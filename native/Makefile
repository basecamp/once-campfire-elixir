# Builds the isolated Gumbo HTML parser into priv/native (invoked by elixir_make).
PRIV := $(MIX_APP_PATH)/priv/native
HTML := $(PRIV)/campfire-html
LEGACY_NIF := $(PRIV)/campfire_html.so
PLATFORM := $(shell erl -noshell -eval 'io:format("~ts-~ts", [erlang:system_info(otp_release), erlang:system_info(system_architecture)]), halt().')
BUILD_DIR := $(abspath $(MIX_APP_PATH)/../../native/$(PLATFORM))
HTML_ARTIFACT := $(BUILD_DIR)/campfire-html
GUMBO := $(wildcard vendor/gumbo/src/*.c)

all: $(HTML_ARTIFACT)
	@mkdir -p $(PRIV)
	@rm -f $(LEGACY_NIF)
	@tmp="$(HTML).tmp.$$$$"; \
		cp $(HTML_ARTIFACT) "$$tmp" && mv -f "$$tmp" $(HTML) || \
		{ status=$$?; rm -f "$$tmp"; exit $$status; }

$(HTML_ARTIFACT): html.c $(GUMBO) $(wildcard vendor/gumbo/src/*.h)
	@mkdir -p $(BUILD_DIR)
	$(CC) -O2 -std=c99 -Ivendor/gumbo/src html.c $(GUMBO) -o $@

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(HTML)
	rm -f $(LEGACY_NIF)

.PHONY: all clean
