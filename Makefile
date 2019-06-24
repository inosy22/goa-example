APP_NAME := calc
REPO := goa-example
SWAGGER_DIR := ./swagger-ui

# goa-cliのインストール
goa-install:
	go get -u goa.design/goa/v3
	go get -u goa.design/goa/v3/...
	go mod tidy

# `goa gen`コマンドの実行と、swagger-ui用ファイルの準備
goa-gen:
	@goa gen $(REPO)/design
	@cp -f ./gen/http/openapi.json ${SWAGGER_DIR}/swagger.json \
	&& echo "var spec = `cat ${SWAGGER_DIR}/swagger.json`" > ${SWAGGER_DIR}/swagger.js

# `goa example`コマンドの実行と、controllerファイルの移動
goa-example:
	@goa example $(REPO)/design
	# ルートディレクトリにできるファイルをcontrollerへ移動 (BSD sedなのでMacでの動作想定)
	@mv -n ./*.go controller/ \
	&& sed -i .bak "s/\"$(REPO)\"/\"$(REPO)\/controller\"/g" cmd/$(APP_NAME)/main.go \
	&& rm -f cmd/$(APP_NAME)/main.go.bak \
	&& rm -f ./*.go

# buildのみ
goa-build:
	@cd cmd/$(APP_NAME) && go build

# buildして実行
goa-run:
	@make goa-build
	@./cmd/$(APP_NAME)/$(APP_NAME)

# swagger-uiの表示
swagger:
	@open $(SWAGGER_DIR)/index.html
