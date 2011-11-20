#include "struct.h"
#include "util.h"
#include <sys/stat.h>
#include <string.h>


// file


#ifdef FILE_RW


#define INPUT_MAX_LEN	10000
#define ERROR_BIG		"Input file is too big"


long fsize(FILE* file) {
	if (!fseek(file, 0, SEEK_END)) {
		long size = ftell(file);
		if (size >= 0 && !fseek(file, 0, SEEK_SET))
			return size;
	}
	return -1;
}

struct byte_array *read_file(const struct byte_array *filename_ba)
{
	FILE * file;
	size_t read;
	uint8_t *str;
	long size;
	
	struct stat st;
	const char* filename_str = byte_array_to_string(filename_ba);
	if (stat(filename_str, &st)) {
		DEBUGPRINT("%s does not exist\n", filename_str);
		return 0;
	}
	
	if (!(file = fopen(filename_str, "rb")))
		exit_message(ERROR_FOPEN);
	if ((size = fsize(file)) < 0)
		exit_message(ERROR_FSIZE);
	else if (size > INPUT_MAX_LEN)
		exit_message(ERROR_BIG);
	if (!(str = malloc((size_t)size)))// + 1)))
		exit_message(ERROR_ALLOC);
	
	read = fread(str, 1, (size_t)size, file);
	if (feof(file) || ferror(file))
		exit_message(ERROR_FREAD);
	//str[read] = 0;
	
	if (fclose(file))
		exit_message(ERROR_FCLOSE);
	
	struct byte_array* ba = byte_array_new_size(read);
	ba->data = ba->current = str;
	return ba;
}

int write_byte_array(struct byte_array* ba, FILE* file) {
	uint16_t len = ba->size;
	int n = fwrite(ba->data, 1, len, file);
	return len - n;
}

int write_file(const struct byte_array* filename, struct byte_array* bytes)
{
	DEBUGPRINT("write_file\n");
	const char *fname = byte_array_to_string(filename);
	FILE* file = fopen(fname, "w");
	if (!file) {
		DEBUGPRINT("could not open file %s\n", fname);
		return -1;
	}
	//struct byte_array* bytes = byte_array_new();
	//serial_encode_string(bytes, 0, data);
	int r = fwrite(bytes->data, 1, bytes->size, file);
	DEBUGPRINT("\twrote %d bytes\n", r);
	int s = fclose(file);
	DEBUGPRINT("write_file done\n");
	return (r<0) || s;
}

char* build_path(const char* dir, const char* name)
{
	int dirlen = dir ? strlen(dir) : 0;
	char* path = malloc(dirlen + 1 + strlen(name));
	const char* slash = (dir && dirlen && (dir[dirlen] != '/')) ? "/" : "";
	sprintf(path, "%s%s%s", dir ? dir : "", slash, name);
	return path;
}

#endif // FILE_RW
