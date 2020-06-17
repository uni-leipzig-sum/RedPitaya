
#include <stdarg.h>
#include "common.h"


int join_uints(char **buf, size_t *bufsize, size_t offset, unsigned int *uints, size_t num_uints)
{
	int written = 0;
	for (size_t i = 0; i < num_uints; i++) {
		char *u = NULL;
		int l;
		l = safe_sprintf(&u, i==0?"%u":",%u", uints[i]);
		if (l < 0) {
			free(*buf);
			*buf = NULL;
			return -1;
		}
		if (*bufsize-offset < written+l+1) {
			*bufsize += 1024;
			*buf = realloc(*buf, *bufsize);
			if (*buf == NULL)
				return -1;
		}
		memcpy(*buf+offset+written, u, l+1);
		written += l;
		free(u);
	}
	return written;
}

// Safe implementation of sprintf. buffer will be allocated by the function
// and must be freed by the caller.
// Returns the string length excluding the terminating zero char!
int safe_sprintf(char **buf, const char *format, ...)
{
	va_list arguments;
	va_start(arguments, format);
	const int len = vsnprintf(NULL, 0, format, arguments);
	va_end(arguments);
	if (*buf) {
		free(*buf);
		*buf = NULL;
	}
	if (!(*buf = malloc((len + 1) * sizeof(char)))) {
		*buf = NULL;
		return -1;
	}
	va_start(arguments, format);
	vsnprintf(*buf, (size_t)(len + 1), format, arguments);
	va_end(arguments);
	return len;
}
