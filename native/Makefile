# Builds the Gumbo HTML parser and SQLite read NIFs into priv/native (invoked by elixir_make).
# The SQLite NIF links the system library, so it is only built when Exqlite does too
# (EXQLITE_USE_SYSTEM): two copies of SQLite in one process must not share a database file.
ERTS_INCLUDE_DIR ?= $(shell erl -noshell -eval 'io:format("~ts/erts-~ts/include", [code:root_dir(), erlang:system_info(version)]), halt().')
PRIV := $(MIX_APP_PATH)/priv/native
NIF := $(PRIV)/campfire_html.so
SQLITE := $(PRIV)/campfire_sqlite.so
GUMBO := $(wildcard vendor/gumbo/src/*.c)

CFLAGS += -O2 -std=c99 -fPIC -I$(ERTS_INCLUDE_DIR) -Ivendor/gumbo/src
ifeq ($(shell uname -s),Darwin)
  LDFLAGS += -dynamiclib -undefined dynamic_lookup
else
  LDFLAGS += -shared
endif

ifeq ($(EXQLITE_USE_SYSTEM),)
all: $(NIF)
	@rm -f $(SQLITE)
else
all: $(NIF) $(SQLITE)
endif

$(SQLITE): sqlite_read.c
	@mkdir -p $(PRIV)
	$(CC) -O2 -std=c11 -fPIC -Wall -Wextra -Werror -I$(ERTS_INCLUDE_DIR) sqlite_read.c $(LDFLAGS) -o $@ -lsqlite3

$(NIF): html_nif.c $(GUMBO) $(wildcard vendor/gumbo/src/*.h)
	@mkdir -p $(PRIV)
	$(CC) $(CFLAGS) html_nif.c $(GUMBO) $(LDFLAGS) -o $@

clean:
	rm -f $(NIF) $(SQLITE)

.PHONY: all clean
