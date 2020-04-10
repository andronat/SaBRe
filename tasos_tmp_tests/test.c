#include <fcntl.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char const *argv[]) {
  char test[] = "/home/vagrant/fftplog";
  char *buf = (char *)malloc(sizeof(char) * (23));
  strcpy(buf, test);
  openat(0, buf, 0);
  return 0;
}
