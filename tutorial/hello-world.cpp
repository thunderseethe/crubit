#include <cstdio>
#include "tutorial/lib.h"

int main() {
  int x = lib::add_two_integers(100, 12);
  printf("Hello, World %d time(s)!", x);
}
