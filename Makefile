REBAR = $(shell pwd)/rebar3
COVERPATH = $(shell pwd)/_build/test/cover
.PHONY: rel test relgentlerain docker-build docker-run

all: compile

compile:
	$(REBAR) compile

clean:
	$(REBAR) clean
	rm -r _build/default/rel/antidote/antidote* || true

distclean: clean relclean
	$(REBAR) clean --all

cleantests:
	rm -f test/utils/*.beam
	rm -f test/singledc/*.beam
	rm -f test/multidc/*.beam
	rm -rf logs/

shell: rel
	export NODE_NAME=antidote@127.0.0.1 ; \
	export COOKIE=antidote ; \
	export JAVANODE_NAME=JavaNode; \
	export ROOT_DIR_PREFIX=$$NODE_NAME/ ; \
	_build/default/rel/antidote/bin/antidote console ${ARGS}

shell2: rel2
	export NODE_NAME=antidote2@127.0.0.1 ; \
	export COOKIE=antidote ; \
	export ROOT_DIR_PREFIX=$$NODE_NAME/ ; \
	export JAVANODE_NAME=JavaNode2; \
	export CONFIG=config2 ; \
	_build/default/rel/antidote/bin/antidote console ${ARGS}

shellVar: rel
	export NODE_NAME=${NODE_NAME} ; \
	export backend_node=${JAVANODE_NAME}@127.0.0.1; \
	export JAVANODE_NAME=${JAVANODE_NAME}; \
	export COOKIE=antidote ; \
	export ROOT_DIR_PREFIX=$$NODE_NAME/ ; \
	_build/default/rel/antidote/bin/antidote console ${ARGS}

shellremote: rel
	export NODE_NAME=antidote@10.132.9.129; \
	export COOKIE=antidote ; \
	export JAVANODE_NAME=JavaNode; \
	export ROOT_DIR_PREFIX=$$NODE_NAME/ ; \
	_build/default/rel/antidote/bin/antidote console ${ARGS}
#shell:
#	$(REBAR) shell --name='antidote@127.0.0.1' --setcookie antidote --config config/sys-debug.config

#shell1:
#	$(REBAR) shell --name='antidote1@127.0.0.1' --setcookie antidote --config config/sys-debug1.config

# same as shell, but automatically reloads code when changed
# to install add `{plugins, [rebar3_auto]}.` to ~/.config/rebar3/rebar.config
# the tool requires inotifywait (sudo apt install inotify-tools)
# see https://github.com/vans163/rebar3_auto or http://blog.erlware.org/rebar3-auto-comile-and-load-plugin/
#auto:
#	$(REBAR) auto --name='antidote@127.0.0.1' --setcookie antidote --config config/sys-debug.config

rel:
	export REBAR_CONFIG="rebar.config" ; \
	$(REBAR) release

rel2:
	export REBAR_CONFIG="rebar2.config" ; \
	$(REBAR) release

relclean:
	rm -rf _build/default/rel

reltest: rel
	test/release_test.sh

# style checks
lint:
	${REBAR} as lint lint

check: distclean cleantests test reltest dialyzer lint

relgentlerain: export TXN_PROTOCOL=gentlerain
relgentlerain: relclean cleantests rel

relnocert: export NO_CERTIFICATION=true
relnocert: relclean cleantests rel

stage :
	$(REBAR) release -d

compile-utils: compile
	for filename in "test/utils/*.erl" ; do \
		erlc -o test/utils $$filename ; \
	done

test:
	${REBAR} eunit skip_deps=true

coverage:
	# copy the coverdata files with a wildcard filter
	# won't work if there are multiple folders (multiple systests)
	cp logs/*/*singledc*/../all.coverdata ${COVERPATH}/singledc.coverdata ; \
	cp logs/*/*multidc*/../all.coverdata ${COVERPATH}/multidc.coverdata ; \
	${REBAR} cover --verbose

singledc: compile-utils rel
	rm -f test/singledc/*.beam
	mkdir -p logs
ifdef SUITE
	ct_run -pa ./_build/default/lib/*/ebin test/utils/ -logdir logs -suite test/singledc/${SUITE} -cover test/antidote.coverspec
else
	ct_run -pa ./_build/default/lib/*/ebin test/utils/ -logdir logs -dir test/singledc -cover test/antidote.coverspec
endif

multidc: compile-utils rel
	rm -f test/multidc/*.beam
	mkdir -p logs
ifdef SUITE
	ct_run -pa ./_build/default/lib/*/ebin test/utils/ -logdir logs -suite test/multidc/${SUITE} -cover test/antidote.coverspec
else
	ct_run -pa ./_build/default/lib/*/ebin test/utils/ -logdir logs -dir test/multidc -cover test/antidote.coverspec
endif

systests: singledc multidc

docs:
	${REBAR} doc skip_deps=true

xref: compile
	${REBAR} xref skip_deps=true

dialyzer:
	${REBAR} dialyzer

docker-build:
	tmpdir=`mktemp -d` ; \
	wget "https://raw.githubusercontent.com/AntidoteDB/docker-antidote/master/local-build/Dockerfile" -O "$$tmpdir/Dockerfile" ; \
	docker build -f $$tmpdir/Dockerfile -t antidotedb:local-build .

docker-run: docker-build
	docker run -d --name antidote -p "8087:8087" antidotedb:local-build

docker-clean:
ifneq ($(docker images -q antidotedb:local-build 2> /dev/null), "")
	docker image rm -f antidotedb:local-build
endif
