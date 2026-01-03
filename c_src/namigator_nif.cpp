// c_src/namigator_nif.cpp
#include <fine.hpp>

int64_t test_add(ErlNifEnv* env, int64_t a, int64_t b) {
    return a + b;
}

FINE_NIF(test_add, 0);
FINE_INIT("Elixir.Namigator.NIF");
