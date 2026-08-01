# KernelLens reference environment. See env/README.md.
.PHONY: all setup images kernel rootfs run smoke src src-export clean distclean

all: images

setup:            ## one-time host setup (macOS)
	scripts/host-setup-macos.sh

images:           ## build kernel + rootfs (in Docker)
	scripts/build-all.sh

kernel:
	scripts/build-all.sh kernel

rootfs:
	scripts/build-all.sh rootfs

run:              ## boot interactive VM (exit: Ctrl-a x)
	./run.sh

src:              ## shell into the kernel source tree (Docker volume)
	@echo "Opening a shell INSIDE the build container, at the kernel source tree."
	@echo "This is the real tree used by 'make kernel' — edit here to change the kernel."
	@echo "(To just READ source in your editor, open env/src/ instead; refresh it"
	@echo " with 'make src-export'.)  Exit the shell with Ctrl-d."
	docker run --rm -it -v kernel-lens-cache:/work/cache -w /work/cache/linux-$$(. ./config.sh; echo $$KERNEL_VERSION) kernel-lens-build bash

src-export:       ## copy source to env/src/ for host-side BROWSING ONLY
	@echo "Exporting source to env/src/ (browsing copy — a few case-colliding"
	@echo "files are lost on macOS; never build from this copy, use 'make src')"
	docker run --rm -v kernel-lens-cache:/work/cache -v "$(CURDIR)/src:/out" \
	  kernel-lens-build sh -c 'rsync -a --delete \
	    --exclude="*.o" --exclude="*.a" --exclude="*.cmd" --exclude=".*.cmd" \
	    --exclude="*.mod" --exclude="*.mod.c" --exclude=".tmp*" \
	    --exclude="vmlinux*" --exclude="System.map" --exclude="modules.*" \
	    /work/cache/linux-*/ /out/'

smoke:            ## boot headless + verify observability contract
	scripts/smoke-test.sh

clean:            ## remove built artifacts, keep downloads
	rm -rf dist

distclean: clean  ## remove everything including source cache
	rm -rf cache
	-docker volume rm kernel-lens-cache
