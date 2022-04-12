TAG_PREFIX := quay.io/zregvart_redhat
POLICIES := $(wildcard */.)

all: $(POLICIES)

$(POLICIES):
	$(eval TAG := $(TAG_PREFIX)/${@:/.=}:v1)
	docker build -t $(TAG) $@
	docker push $(TAG)

.PHONY: all $(POLICIES)