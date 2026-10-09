# Builds the Gumbo HTML parser and SQLite NIFs into priv/native (invoked by elixir_make).
PRIV := $(MIX_APP_PATH)/priv/native
NIF := $(PRIV)/campfire_html.so
LEGACY_HTML := $(PRIV)/campfire-html
PLATFORM := $(shell erl -noshell -eval 'io:format("~ts-~ts", [erlang:system_info(otp_release), erlang:system_info(system_architecture)]), halt().')
ERTS_INCLUDE_DIR ?= $(shell erl -noshell -eval 'io:format("~ts/erts-~ts/include", [code:root_dir(), erlang:system_info(version)]), halt().')
BUILD_DIR := $(abspath $(MIX_APP_PATH)/../../native/$(PLATFORM))
NIF_ARTIFACT := $(BUILD_DIR)/campfire_html.so
SQLITE_NIF := $(PRIV)/campfire_sqlite.so
SQLITE_ARTIFACT := $(BUILD_DIR)/campfire_sqlite.so
# The system SQLite, as production linked through exqlite's EXQLITE_USE_SYSTEM.
SQLITE_CFLAGS := $(shell pkg-config --cflags sqlite3 2>/dev/null)
SQLITE_LIBS := $(or $(shell pkg-config --libs sqlite3 2>/dev/null),-lsqlite3)
GUMBO := $(wildcard vendor/gumbo/src/*.c)

# GUMBO_NIF makes allocation failures recoverable; NDEBUG keeps Gumbo's internal
# assertions from aborting the VM.
CFLAGS += -O2 -std=c11 -fPIC -DGUMBO_NIF -DNDEBUG -I$(ERTS_INCLUDE_DIR) -Ivendor/gumbo/src
ifeq ($(shell uname -s),Darwin)
  LDFLAGS += -dynamiclib -undefined dynamic_lookup
else
  LDFLAGS += -shared
endif

all: $(NIF_ARTIFACT) $(SQLITE_ARTIFACT)
	@mkdir -p $(PRIV)
	@rm -f $(LEGACY_HTML)
	@for pair in "$(NIF_ARTIFACT):$(NIF)" "$(SQLITE_ARTIFACT):$(SQLITE_NIF)"; do \
		from=$${pair%%:*}; to=$${pair#*:}; tmp="$$to.tmp.$$$$"; \
		cp "$$from" "$$tmp" && mv -f "$$tmp" "$$to" || { status=$$?; rm -f "$$tmp"; exit $$status; }; \
	done

$(NIF_ARTIFACT): html_nif.c $(GUMBO) $(wildcard vendor/gumbo/src/*.h)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) html_nif.c $(GUMBO) $(LDFLAGS) -o $@

$(SQLITE_ARTIFACT): sqlite_nif.c
	@mkdir -p $(BUILD_DIR)
	$(CC) -O2 -std=c11 -fPIC -Wall -I$(ERTS_INCLUDE_DIR) $(SQLITE_CFLAGS) sqlite_nif.c $(LDFLAGS) $(SQLITE_LIBS) -o $@

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(NIF) $(SQLITE_NIF) $(LEGACY_HTML)

.PHONY: all clean
