.PHONY: test lint package install
test:
	python3 -m unittest discover -s tests -v
lint:
	python3 -m compileall -q src tests
	qmllint contents/ui/*.qml
package:
	./scripts/package.sh
install:
	./scripts/install.sh
