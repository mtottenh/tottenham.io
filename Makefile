CC=hugo
SRCDIR=./src
DESTDIR=./build
TESTDIR=./test

all: build

build:
	cd $(SRCDIR) && $(CC) --destination ../$(DESTDIR)

serve:
	cd $(SRCDIR) && $(CC) $@ --theme=hello-friend-ng 

clean:
	-rm -rf $(DESTDIR)
	-rm -rf $(TESTDIR)

.PHONY: build all
