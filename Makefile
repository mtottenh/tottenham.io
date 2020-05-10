CC=bundler exec jekyll
SRCDIR=./src
DESTDIR=./build
TESTDIR=./test

all: build

build:
	$(CC) $@ --source $(SRCDIR) --destination $(DESTDIR)

serve:
	$(CC) $@ --source $(SRCDIR) --destination $(TESTDIR) --drafts

clean:
	-rm -rf $(DESTDIR)
	-rm -rf $(TESTDIR)

.PHONY: build all
