# Makefile for Xamrock CLI

PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
INSTALL_NAME = xamrock

.PHONY: build install uninstall clean

# Build the CLI in release mode
build:
	swift build -c release

# Install the CLI to the system
install: build
	install -d $(BINDIR)
	install -m 755 .build/release/XamrockCLI $(BINDIR)/$(INSTALL_NAME)

# Uninstall the CLI from the system
uninstall:
	rm -f $(BINDIR)/$(INSTALL_NAME)

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build
