# WhalePeak - convenience targets for installation and updates.
#
#   make install     install or update the applet
#   make update      update and restart plasmashell
#   make check       compare source and installed version
#   make uninstall   remove the applet and the icon
#   make package     build dist/whalepeak.plasmoid
#   make test        run the unit tests
#   make probe       render and check the timeline without plasmashell
#   make images      render the images in assets/ (README)
#   make lint        check the QML files with qmllint
#   make lint-md     check README.md with markdownlint (npx)
#   make bump VERSION=1.1.0   set the version in metadata.json
#   make clean       delete the build folder dist/

SHELL := bash

.PHONY: help install update check uninstall package test probe images lint lint-md bump clean

help:
	@echo "WhalePeak"
	@echo ""
	@echo "  make install     install or update the applet"
	@echo "  make update      update and restart plasmashell"
	@echo "  make check       compare source and installed version"
	@echo "  make uninstall   remove the applet and the icon"
	@echo "  make package     build dist/whalepeak.plasmoid"
	@echo "  make test        run the unit tests"
	@echo "  make probe       render and check the timeline without plasmashell"
	@echo "  make images      render the images in assets/ (README)"
	@echo "  make lint        check the QML files with qmllint"
	@echo "  make lint-md     check README.md with markdownlint (npx)"
	@echo "  make bump VERSION=1.1.0   set the version in metadata.json"
	@echo "  make clean       delete the build folder dist/"

install:
	@tools/install.sh

update:
	@tools/install.sh --restart

check:
	@tools/install.sh --check

uninstall:
	@tools/uninstall.sh

package:
	@tools/package.sh

test:
	@node --test tests/*.js

probe:
	@tools/probe-timeline.sh

images:
	@tools/render-images.sh

lint:
	@command -v qmllint >/dev/null 2>&1 || { echo 'qmllint missing (package qt6-declarative-dev-tools).'; exit 2; }
	@qmllint contents/ui/*.qml contents/config/*.qml && echo "qmllint: no findings."

lint-md:
	@npx --yes markdownlint-cli@0.43.0 README.md && echo "markdownlint: no findings."

bump:
	@test -n "$(VERSION)" || { echo 'Usage: make bump VERSION=1.1.0'; exit 2; }
	@tools/bump-version.sh "$(VERSION)"

clean:
	@rm -rf dist
	@echo "dist/ removed."
