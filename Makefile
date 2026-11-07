.PHONY: test test-qml lint package install
QMLTESTRUNNER := $(shell command -v qmltestrunner 2>/dev/null || echo /usr/lib/qt6/bin/qmltestrunner)
test:
	python3 -m unittest discover -s tests -v
test-qml:
	QMLTESTRUNNER=$(QMLTESTRUNNER) bash scripts/test-qml.sh
lint:
	python3 -m compileall -q src tests
	@if command -v qmllint >/dev/null; then qmllint contents/ui/*.qml; else echo "qmllint unavailable; skipped"; fi
package:
	./scripts/package.sh
install:
	./scripts/install.sh
