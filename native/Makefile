# Builds the Gumbo HTML parser NIF into priv/native (invoked by elixir_make).
PRIV := $(MIX_APP_PATH)/priv/native
NIF := $(PRIV)/campfire_html.so
LEGACY_HTML := $(PRIV)/campfire-html
PLATFORM := $(shell erl -noshell -eval 'io:format("~ts-~ts", [erlang:system_info(otp_release), erlang:system_info(system_architecture)]), halt().')
ERTS_INCLUDE_DIR ?= $(shell erl -noshell -eval 'io:format("~ts/erts-~ts/include", [code:root_dir(), erlang:system_info(version)]), halt().')
BUILD_DIR := $(abspath $(MIX_APP_PATH)/../../native/$(PLATFORM))
NIF_ARTIFACT := $(BUILD_DIR)/campfire_html.so
GUMBO := $(wildcard vendor/gumbo/src/*.c)

# GUMBO_NIF makes allocation failures recoverable; NDEBUG keeps Gumbo's internal
# assertions from aborting the VM.
CFLAGS += -O2 -std=c11 -fPIC -DGUMBO_NIF -DNDEBUG -I$(ERTS_INCLUDE_DIR) -Ivendor/gumbo/src
ifeq ($(shell uname -s),Darwin)
  LDFLAGS += -dynamiclib -undefined dynamic_lookup
else
  LDFLAGS += -shared
endif

all: $(NIF_ARTIFACT)
	@mkdir -p $(PRIV)
	@rm -f $(LEGACY_HTML)
	@tmp="$(NIF).tmp.$$$$"; \
		cp $(NIF_ARTIFACT) "$$tmp" && mv -f "$$tmp" $(NIF) || \
		{ status=$$?; rm -f "$$tmp"; exit $$status; }

$(NIF_ARTIFACT): html_nif.c $(GUMBO) $(wildcard vendor/gumbo/src/*.h)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) html_nif.c $(GUMBO) $(LDFLAGS) -o $@

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(NIF) $(LEGACY_HTML)

.PHONY: all clean
