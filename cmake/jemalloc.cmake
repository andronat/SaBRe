include (ExternalProject)

set(JEMALLOC_URL https://github.com/jemalloc/jemalloc/releases/download/5.2.1/jemalloc-5.2.1.tar.bz2)
set(JEMALLOC_INSTALL ${CMAKE_CURRENT_BINARY_DIR}/jemalloc/install)
set(JEMALLOC_LIB ${CMAKE_CURRENT_BINARY_DIR}/jemalloc/install/lib/libjemalloc.so)

ExternalProject_Add(jemalloc
  PREFIX jemalloc
  URL ${JEMALLOC_URL}
  INSTALL_DIR ${JEMALLOC_INSTALL}
  DOWNLOAD_DIR ${CMAKE_CURRENT_BINARY_DIR}/jemalloc/download
  BUILD_COMMAND $(MAKE)
  BUILD_IN_SOURCE 1
  INSTALL_COMMAND $(MAKE) install
  CONFIGURE_COMMAND
    ${CMAKE_CURRENT_BINARY_DIR}/jemalloc/src/jemalloc/configure
    --prefix=${JEMALLOC_INSTALL}
)
