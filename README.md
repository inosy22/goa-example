# goa-example

https://github.com/goadesign/goa

## 概要
 - Go (v1.12.6) + goa(v3.0.2) を利用する
   - 上記の組み合わせは、後述するGoModulesが標準サポートされている

## usage
```bash
# goa-cli関連のインストール(goaアプリケーション開発環境構築用)
$ make goa-install

# `goa gen`コマンドの実行と、swagger-ui用ファイルの準備
$ make goa-gen

# `goa example`コマンドの実行と、controllerファイルの移動
$ make goa-example

# buildのみ
$ make goa-build

# buildして実行
$ make goa-run

# swagger-uiの表示
$ make swagger
```

## ディレクトリ構造

```bash
├── cmd # `goa example`で初期生成されるアプリケーション起動トリガー
├── design # goaのAPI定義を記述
├── docker # docker関連のファイルを配置する
├── gen # `goa gen`の生成ファイル、手動でいじることはない
├── src # 独自ソースコードの格納 (CleanArchtectureベース)
│   ├── controller # InterfaceAdapters: goaで生成されたController
│   ├── domain # Enterprise BusinessRules: データに関する定義とロジック
│   ├── gateway # InterfaceAdapters: Repository系
│   │   ├── mysql # mysqlとのデータの送受信
│   │   ├── redis # redisとのデータの送受信
│   │   └── http # APIとのデータの送受信
│   └── usecase # ApplicationBusinessRules: Service系
└── swagger-ui # swagger-ui用ファイル
```

## 言語バージョン管理
 - 名前：goenv (2.0.0beta11)
 - URL：https://github.com/syndbg/goenv
 - 特記事項
   - Homebrewから入れると古いので、github記載の方法で入れるのが吉
   - goenv2系からGOPATHも管理してくれるようになっている(つまり、自分で指定しないほうがいい)

```bash
$ git clone https://github.com/syndbg/goenv.git ~/.goenv
$ echo 'export GOENV_ROOT="$HOME/.goenv"' >> ~/.bash_profile
$ echo 'export PATH="$GOENV_ROOT/bin:$PATH"' >> ~/.bash_profile
$ echo 'eval "$(goenv init -)"' >> ~/.bash_profile
# 独自追加begin 記載はなかったが、GOROOTを宣言しないと動かなかったので追加
$ echo 'export GOROOT="$(goenv prefix)"' >> ~/.bash_profile
# 独自追加end 
$ echo 'export PATH="$GOROOT/bin:$PATH"' >> ~/.bash_profile
$ echo 'export PATH="$GOPATH/bin:$PATH"' >> ~/.bash_profile

# ※昔のセットアップで、GOPATH,GOBIN等を設定している場合は削除する

# Goの1.12.6のインストール
$ goenv install 1.12.6
```


## 依存関係管理ツール
 - 名前：GoModules
 - URL：https://github.com/golang/go/wiki/Modules
 - 特記事項
   - Go1.12系から標準サポート
   - 前身は「vgo」らしい
   - 標準になっているのでdepは利用せずこちらを使う


## goa導入の軌跡
 - goa (v3.0.2)
 - URL: https://github.com/goadesign/goa
 - 特記事項
   - デザインファーストを謳っているWebフレームワーク
   - goaのDSLからAPI設計を記述し、クライアント周りのコードを自動生成できる

```bash
# プロジェクトディレクトリを作成する
$ mkdir goa-example
$ cd goa-example

# GoModulesを有効にする
$ go mod init goa-example

# goa3系を利用できるようにする
$ go get -u goa.design/goa/v3
$ go get -u goa.design/goa/v3/...

# goaのdesing定義ファイルを作成する
$ mkdir design
$ cat <<EOF > design/design.go
package design

import (
	. "goa.design/goa/v3/dsl"
)

// API describes the global properties of the API server.
var _ = API("calc", func() {
	Title("Calculator Service")
	Description("HTTP service for adding numbers, a goa teaser")
	Server("calc", func() {
		Host("localhost", func() { URI("http://localhost:8088") })
	})
})

// Service describes a service
var _ = Service("calc", func() {
	Description("The calc service performs operations on numbers")
	// Method describes a service method (endpoint)
	Method("add", func() {
		// Payload describes the method payload
		// Here the payload is an object that consists of two fields
		Payload(func() {
			// Attribute describes an object field
			Attribute("a", Int, "Left operand")
			Attribute("b", Int, "Right operand")
			// Both attributes must be provided when invoking "add"
			Required("a", "b")
		})
		// Result describes the method result
		// Here the result is a simple integer value
		Result(Int)
		// HTTP describes the HTTP transport mapping
		HTTP(func() {
			// Requests to the service consist of HTTP GET requests
			// The payload fields are encoded as path parameters
			GET("/add/{a}/{b}")
			// Responses use a "200 OK" HTTP status
			// The result is encoded in the response body
			Response(StatusOK)
		})
	})
})

EOF

# ヒアドキュメントでうまくファイルを作れなければフォーマット
$ go fmt design/design.go

# goaのAPI設計ファイルからコードを生成
$ go gen goa-example/design # genディレクトリだけできる
$ go example goa-example/design # cmdディレクトリができる

# ロジック部分の実装(Addメソッドの戻り値を追記する)
$ vim calc.go
---------
func (s *calcsrvc) Add(ctx context.Context, p *calc.AddPayload) (res int, err error) {
	s.logger.Print("calc.add")
	return p.A + p.B, nil
}
----------

# 実行
$ cd cmd/calc
$ go build
$ ./calc

# 別窓
$ curl localhost:8088/add/1/2
3
```

### goaのcliのインストールについて
GoModulesが不完全なのか、グローバルのcliのインストールにうまく対応できてなさそう。  
苦肉の策で、goaを入れた直後に`go mod tidy`で汚した`go.mod`ファイルを掃除することで解決とする。

`./Makefile`
```
# goa-cliのインストール
goa-install:
	go get -u goa.design/goa/v3
	go get -u goa.design/goa/v3/...
	go mod tidy
```

### goaでのファイルジェネレートについて
 - `./gen`ディレクトリはAPI定義が変わるたびに再生成され、実装者が手動で変更を行わない
 - `./cmd`ディレクトリは最初に自動生成したのちに、実装者が手動で変更を加えられる場所
 - Controllerにあたるようなファイルがルートディレクトリにできてしまう(`./calc.go`)
   - これは`goa example`コマンド実行後に`./src/controller`ディレクトリに移動して、`cmd/calc/main.go`のimportを変える

本来ソースコードの置換は良くないと考えているが、開発時にMac上で1度だけ実行する想定なので妥協

`./Makefile`
```bash
# `goa example`コマンドの実行と、controllerファイルの移動
goa-example:
	@goa example $(REPO)/design
	# ルートディレクトリにできるファイルをcontrollerへ移動 (BSD sedなのでMacでの動作想定)
	@if [ -e ./src ]; then mkdir -p src/controller; fi
	@mv -n ./*.go src/controller/ \
	&& sed -i .bak "s/\"$(REPO)\"/\"$(REPO)\/src\/controller\"/g" cmd/$(APP_NAME)/main.go \
	&& rm -f cmd/$(APP_NAME)/main.go.bak \
	&& rm -f ./*.go
```


### swagger-uiの利用

**※ セキュリティ関係からAPIサーバーとは完全分離することにする**

`goa gen`で`./gen/http/openapi.json`がswaggerのAPI定義ファイルとなっている
これをswagger-uiで読ませるために
https://github.com/swagger-api/swagger-ui/tree/master/dist
の中身を`./swagger-ui`ディレクトリを作成して入れる

`./swagger-ui/index.html`には、swaggerのAPI定義ファイルを読み込む部分があるのでそこを変更する。
```js
const ui = SwaggerUIBundle({
        url: "https://petstore.swagger.io/v2/swagger.json",
```

ローカルファイルで実行する場合にjsonファイルから読み込めないという制約があるみたいなので、
無理矢理jsonをグローバル変数に入れるjsを作ってそれを読み込む。

```bash
$ cp -f ./gen/http/openapi.json ./swagger-ui/swagger.json
$ echo "var spec = `cat ./swagger-ui/swagger.json`" > ./swagger-ui/swagger.js
```

`./swagger-ui/index.html
```js
+ <script src="./swagger.js"></script>

- url: "https://petstore.swagger.io/v2/swagger.json",
+ spec: spec,
```

これをAPI定義が変わるたびにやるのは辛いので、Makefileで`goa gen`時に自動実行されるようにする

`./Makefile`
```bash
APP_NAME := calc
REPO := goa-example
SWAGGER_DIR := ./swagger-ui

# `goa gen`コマンドの実行と、swagger-ui用ファイルの準備
goa-gen:
	@goa gen $(REPO)/design
	@cp -f ./gen/http/openapi.json ${SWAGGER_DIR}/swagger.json \
	&& echo "var spec = `cat ${SWAGGER_DIR}/swagger.json`" > ${SWAGGER_DIR}/swagger.js
  
# swagger-uiの表示
swagger:
	@open $(SWAGGER_DIR)/index.html

```
