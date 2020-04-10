/*  Copyright © 2019 Software Reliability Group, Imperial College London
 *
 *  This file is part of SaBRe.
 *
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

void *preeny_socket_sync_to_back(void *fd) {
  int front_fd = (int)fd;
  int back_fd = PREENY_SOCKET(front_fd);
  preeny_socket_sync_loop(back_fd, 1);
  return NULL;
}

void *preeny_socket_sync_to_front(void *fd) {
  int front_fd = (int)fd;
  int back_fd = PREENY_SOCKET(front_fd);
  preeny_socket_sync_loop(0, back_fd);
  return NULL;
}

int socket(int domain, int type, int protocol) {
  int fds[2];
  int front_socket;
  int back_socket;

  if (domain != AF_INET && domain != AF_INET6) {
    preeny_info("Ignoring non-internet socket.");
    return original_socket(domain, type, protocol);
  }

  int r = socketpair(AF_UNIX, type, 0, fds);
  preeny_debug("Intercepted socket()!\n");

  if (r != 0) {
    perror("preeny socket emulation failed:");
    return -1;
  }

  preeny_debug("... created socket pair (%d, %d)\n", fds[0], fds[1]);

  front_socket = fds[0];
  back_socket = dup2(fds[1], PREENY_SOCKET(front_socket));
  close(fds[1]);

  preeny_debug("... dup into socketpair (%d, %d)\n", fds[0], back_socket);

  preeny_socket_threads_to_front[fds[0]] = malloc(sizeof(pthread_t));
  preeny_socket_threads_to_back[fds[0]] = malloc(sizeof(pthread_t));

  r = pthread_create(preeny_socket_threads_to_front[fds[0]], NULL,
                     (void *(*)(void *))preeny_socket_sync_to_front,
                     (void *)front_socket);
  if (r) {
    perror("failed creating front-sync thread");
    return -1;
  }

  r = pthread_create(preeny_socket_threads_to_back[fds[0]], NULL,
                     (void *(*)(void *))preeny_socket_sync_to_back,
                     (void *)front_socket);
  if (r) {
    perror("failed creating back-sync thread");
    return -1;
  }

  return fds[0];
}

int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen) {
  if (preeny_desock_did_accept)
    exit(0);
  preeny_desock_did_accept = 1;

  // initialize a sockaddr_in for the peer
  struct sockaddr_in peer_addr;
  memset(&peer_addr, '0', sizeof(struct sockaddr_in));

  // Set the contents in the peer's sock_addr.
  // Make sure the contents will simulate a real client that connects with
  the
      // intercepted server, as the server may depend on the contents to make
      further
          // decisions. The followings set-up should be fine with Nginx.
          peer_addr.sin_family = AF_INET;
  peer_addr.sin_addr.s_addr = htonl(INADDR_ANY);
  peer_addr.sin_port = htons(9000);

  // copy the initialized peer_addr back to the original sockaddr. Note the
  // space for the original sockaddr, namely addr, has already been allocated
  if (addr)
    memcpy(addr, &peer_addr, sizeof(struct sockaddr_in));

  if (preeny_socket_threads_to_front[sockfd])
    return dup(sockfd);
  else
    return original_accept(sockfd, addr, addrlen);
}

int accept4(int sockfd, struct sockaddr *addr, socklen_t *addrlen, int flags) {
  return accept(sockfd, addr, addrlen);
}

int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
  if (preeny_socket_threads_to_front[sockfd]) {
    preeny_info("Emulating bind on port %d\n",
                ntohs(((struct sockaddr_in *)addr)->sin_port));
    return 0;
  } else {
    return original_bind(sockfd, addr, addrlen);
  }
}

int listen(int sockfd, int backlog) {
  if (preeny_socket_threads_to_front[sockfd])
    return 0;
  else
    return original_listen(sockfd, backlog);
}

int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
  if (preeny_socket_threads_to_front[sockfd])
    return 0;
  else
    return original_connect(sockfd, addr, addrlen);
}
