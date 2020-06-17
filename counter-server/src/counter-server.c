/**
 * @brief Red Pitaya counter server implementation
 *
 * @Author Lukas Botsch <lukas.botsch@uni-leipzig.de>
 *
 * This part of code is written in C programming language.
 * Please visit http://en.wikipedia.org/wiki/C_(programming_language)
 * for more details on the language used herein.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>

#include <netinet/in.h>
#include <sys/prctl.h>
#include <errno.h>
#include <arpa/inet.h>
#include <signal.h>
#include <unistd.h>
#include <syslog.h>

#include "common.h"
#include "command.h"


#define MIN(X, Y) (((X) < (Y)) ? (X) : (Y))
#define MAX(X, Y) (((X) > (Y)) ? (X) : (Y))

#define LISTEN_BACKLOG 50
#define LISTEN_PORT 5000
#define MAX_BUFF_SIZE 1024
#define MAX_ARGS 16

static bool app_exit = false;
static char delimiter[] = "\r\n";


static void handleCloseChildEvents()
{
  struct sigaction sigchld_action = {
    .sa_handler = SIG_DFL,
    .sa_flags = SA_NOCLDWAIT
  };
  sigaction(SIGCHLD, &sigchld_action, NULL);
}


static void termSignalHandler(int signum)
{
  app_exit = true;
  syslog (LOG_NOTICE, "Received terminate signal. Exiting...");
}


static void installTermSignalHandler()
{
  struct sigaction action;
  memset(&action, 0, sizeof(struct sigaction));
  action.sa_handler = termSignalHandler;
  sigaction(SIGTERM, &action, NULL);
  sigaction(SIGINT, &action, NULL);
}

/**
 * Helper method which returns next command position from the buffer.
 * @param buffer     Input buffer
 * @param bufferLen  Input buffer length
 * @return Position of next command within buffer, or -1 if not found.
 */
static size_t getNextCommand(const char* buffer, size_t bufferLen)
{
  size_t delimiterLen = sizeof(delimiter) - 1; // dont count last null char.
  size_t i = 0;

  RP_LOG(LOG_INFO, "Begin: getNextCommand\n");
  
  for (i = 0; i < bufferLen; i++) {

    // Find match for end of delimiter
    if (buffer[i] == delimiter[delimiterLen - 1]) {

      // Now go back checking if all delimiter character matches
      size_t dist = 0;
      while (i - dist >= 0 && delimiterLen - dist > 0) {
        if (buffer[i - dist] != delimiter[delimiterLen - dist - 1]) {
          break;
        }
        if (delimiterLen - dist - 1 == 0) {
          return i + 1; // Position of next command
        }

        dist++;
      }
    }
  }

  // No match found
  return -1;
}


/**
 * This parses a command line received from a client. Commands are terminated by '\r\n'
 * and composed of a command name, e.g. COUNTER:COUNT, and an optional argument list. Each
 * part of the command is separated by a ' ' (space) character.
 *
 * When a command is successfully parsed, the registered command handler is called.
 * The command handler returns a response string, that is given back to the caller.
 *
 * @param cmdstr The command string received from the client
 * @param res A string pointer that will point to the response string. The caller takes
 *            ownership of this string and should free it.
 * @param resLen An integer pointer that will point to the length of the response string
 *               (excluding the terminating zero byte)
 * @return 0 on success, >0 on failure
 */
static int parseCommand(char *cmdstr, char **res, size_t *resLen)
{
  char *tok;
  char *cmd;
  char *args[MAX_ARGS+1];
  int nargs = 0;

  // Tokenize
  RP_LOG(LOG_INFO, "Tokenizing command\n");
  cmd = strtok(cmdstr, " ,");
  while ((tok = strtok(NULL, " ,")) != NULL)
    args[nargs++] = tok;

  // Match command
  RP_LOG(LOG_INFO, "Matching command\n");
  command_map_t *p = counter_context.cmdlist;
  while(p->cmd != NULL) {
    if (strcmp(p->cmd, cmd) == 0)
	    break;
    p++;
  }
  if (p->cmd == NULL) {
    RP_LOG(LOG_ERR, "Received unknown command (%s)", cmd);
	*resLen = safe_sprintf(res, "ERR: Unknown command %s", cmd);
    return 1;
  }

  // Call the handler
  RP_LOG(LOG_INFO, "Calling command handler\n");
  return p->handler(nargs, args, res, resLen);
}

/**
 * This is main method of every child process. Here communication with client is handled.
 * @param connfd The communication port
 * @return 0 on success, >0 if an error occurred.
 */
static int handleConnection(int connfd) {
  int read_size;

  size_t message_len = MAX_BUFF_SIZE;
  char *message_buff = malloc(message_len);
  char buffer[MAX_BUFF_SIZE];
  size_t msg_end = 0;

  installTermSignalHandler();

  prctl( 1, SIGTERM );

  RP_LOG(LOG_INFO, "Waiting for first client request.");

  //Receive a message from client
  while( (read_size = recv(connfd , buffer , MAX_BUFF_SIZE , 0)) > 0 )
    {
      if (app_exit) {
        break;
      }

	  RP_LOG(LOG_INFO, "Got message\n");
	  
      // First make sure that message buffer is large enough
      while (msg_end + read_size >= message_len) {
        message_len *= 2;
        message_buff = realloc(message_buff, message_len);
      }

      // Copy read buffer into message buffer
      memcpy(message_buff + msg_end, buffer, read_size);
      msg_end += read_size;

      // Now try to parse each command out
      char *m = message_buff;
      size_t pos = -1;
      while ((pos = getNextCommand(m, msg_end)) != -1) {
		  
        //Parse command
        size_t cmdLen = pos-sizeof(delimiter)+1;
        m[cmdLen] = 0; // split the command string before the termination character
		RP_LOG(LOG_INFO, "Got command: %s\n", m);
        char *res = NULL;
        size_t resLen = 0;
        parseCommand(m, &res, &resLen);

		RP_LOG(LOG_INFO, "Processed command. Got response: %s\n", res);

        // Send the response (if any) back to the client
        if (res != NULL) {
          //Append delimiter to the response
          //Note: as the socket is not buffered, this results in
          //less tcp frames (ideally only one) instead of at least two
          res = realloc(res, resLen + sizeof(delimiter));
          memcpy(res+resLen, delimiter, sizeof(delimiter));
          resLen += (sizeof(delimiter)-1);

          //Send response to client
          write(connfd, res, resLen);
          free(res);
		  res = NULL;
        }

        m += pos;
        msg_end -= pos;
      }

      // Move the rest of the message to the beginning of the buffer
      if (message_buff != m && msg_end > 0) {
        memmove(message_buff, m, msg_end);
      }

      RP_LOG(LOG_INFO, "Waiting for next client request.\n");
    }

  free(message_buff);

  RP_LOG(LOG_INFO, "Closing client connection...");

  if(read_size == 0)
    {
      RP_LOG(LOG_INFO, "Client is disconnected");
      return 0;
    }
  else if(read_size == -1)
    {
      RP_LOG(LOG_ERR, "Receive message failed (%s)", strerror(errno));
      perror("Receive message failed");
      return 1;
    }
  return 0;
}


/**
 * Main daemon entrance point. Opens a socket and listens for any incoming connection.
 * When client connects, if forks the conversation into a new socket and the daemon (parent process)
 * waits for another connection. It can handle multiple connections simultaneously.
 * @param argc  not used
 * @param argv  not used
 * @return
 */
int main(int argc, char *argv[])
{

  // Open logging into "/var/log/messages" or /var/log/syslog" or other configured...
  setlogmask (LOG_UPTO (LOG_INFO));
  openlog ("counter-server", LOG_CONS | LOG_PID | LOG_NDELAY, LOG_LOCAL1);

  RP_LOG (LOG_NOTICE, "counter-server started");

  installTermSignalHandler();

  int listenfd = 0, connfd = 0;
  struct sockaddr_in serv_addr;

  // Handle close child events
  handleCloseChildEvents();


  int result = rp_Init();
  if (result != RP_OK) {
    RP_LOG(LOG_ERR, "Failed to initialize RP APP library: %s", rp_GetError(result));
    return (EXIT_FAILURE);
  }

  result = rp_Reset();
  if (result != RP_OK) {
    RP_LOG(LOG_ERR, "Failed to reset RP APP: %s", rp_GetError(result));
    return (EXIT_FAILURE);
  }

  // Create a socket
  listenfd = socket(AF_INET, SOCK_STREAM, 0);
  if (listenfd == -1)
    {
      RP_LOG(LOG_ERR, "Failed to create a socket (%s)", strerror(errno));
      perror("Failed to create a socket");
      return (EXIT_FAILURE);
    }

  memset(&serv_addr, '0', sizeof(serv_addr));

  serv_addr.sin_family = AF_INET;
  serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);
  serv_addr.sin_port = htons(LISTEN_PORT);

  if (bind(listenfd, (struct sockaddr*)&serv_addr, sizeof(serv_addr)) == -1)
    {
      RP_LOG(LOG_ERR, "Failed to bind the socket (%s)", strerror(errno));
      perror("Failed to bind the socket");
      return (EXIT_FAILURE);
    }

  if (listen(listenfd, LISTEN_BACKLOG) == -1)
    {
      RP_LOG(LOG_ERR, "Failed to listen on the socket (%s)", strerror(errno));
      perror("Failed to listen on the socket");
      return (EXIT_FAILURE);
    }

  RP_LOG(LOG_INFO, "Server is listening on port %d\n", LISTEN_PORT);

  // Socket is opened and listening on port. Now we can accept connections
  while(1)
    {
      struct sockaddr_in cliaddr;
      socklen_t clilen;
      clilen = sizeof(cliaddr);

      connfd = accept(listenfd, (struct sockaddr *)&cliaddr, &clilen);

      if (app_exit == true) {
        break;
      }

      if (connfd == -1) {
        RP_LOG(LOG_ERR, "Failed to accept connection (%s)", strerror(errno));
        perror("Failed to accept connection\n");
        return (EXIT_FAILURE);
      }

      // Fork a child process, which will talk to the client
      if (!fork()) {

        RP_LOG(LOG_INFO, "Connection with client ip %s established.", inet_ntoa(cliaddr.sin_addr));

        // this is the child process
        close(listenfd); // child doesn't need the listener

        result = handleConnection(connfd);

        close(connfd);

        RP_LOG(LOG_INFO, "Closing connection with client ip %s.", inet_ntoa(cliaddr.sin_addr));

        if (result == 0) {
          return(EXIT_SUCCESS);
        }
        else {
          return(EXIT_FAILURE);
        }
      }

      close(connfd);
    }

  close(listenfd);

  result = rp_Release();
  if (result != RP_OK) {
    RP_LOG(LOG_ERR, "Failed to release RP App library: %s", rp_GetError(result));
  }


  RP_LOG(LOG_INFO, "counter-server stopped.");

  closelog ();

  return (EXIT_SUCCESS);
}
