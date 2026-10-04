# Builds the Gumbo HTML parser NIF into priv/native (invoked by elixir_make).
ERTS_INCLUDE_DIR ?= $(shell erl -noshell -eval 'io:format("~ts/erts-~ts/include", [code:root_dir(), erlang:system_info(version)]), halt().')
PRIV := $(MIX_APP_PATH)/priv/native
NIF := $(PRIV)/campfire_html.so
GUMBO := $(wildcard vendor/gumbo/src/*.c)

CFLAGS += -O2 -std=c99 -fPIC -I$(ERTS_INCLUDE_DIR) -Ivendor/gumbo/src
ifeq ($(shell uname -s),Darwin)
  LDFLAGS += -dynamiclib -undefined dynamic_lookup
else
  LDFLAGS += -shared
endif

all: $(NIF)

$(NIF): html_nif.c $(GUMBO) $(wildcard vendor/gumbo/src/*.h)
	@mkdir -p $(PRIV)
	$(CC) $(CFLAGS) html_nif.c $(GUMBO) $(LDFLAGS) -o $@

clean:
	rm -f $(NIF)

.PHONY: all clean
