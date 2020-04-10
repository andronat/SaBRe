#include <assert.h>
#include <fcntl.h>
#include <libgen.h>
#include <stdlib.h>
#include <string.h>
#include <zbox.h>

int main(int argc, char const *argv[]) {

  char pathname[] = "/home/vagrant/fftplog";

  int ret = zbox_init_env();
  assert(!ret);

  // opener
  zbox_opener opener = zbox_create_opener();
  zbox_opener_ops_limit(opener, ZBOX_OPS_INTERACTIVE);
  zbox_opener_mem_limit(opener, ZBOX_MEM_INTERACTIVE);
  zbox_opener_cipher(opener, ZBOX_CIPHER_XCHACHA);
  zbox_opener_create(opener, true);
  zbox_opener_version_limit(opener, 1);

  // open repo
  zbox_repo repo;
  ret = zbox_open_repo(&repo, opener, "mem://sabre", "password");
  assert(!ret);
  zbox_free_opener(opener);

  zbox_file file;

  if (zbox_repo_path_exists(repo, pathname)) {
    // open the existing file
    int ret = zbox_repo_open_file(file, repo, pathname);
    assert(!ret);
  } else {
    // create file
    char *pathname_dup = strdup(pathname);
    assert(pathname_dup != NULL);

    int ret = zbox_repo_create_dir_all(repo, dirname(pathname_dup));
    assert(!ret);
    free(pathname_dup);

    ret = zbox_repo_create_file(file, repo, pathname);
    assert(!ret);
  }

  return 0;
}
