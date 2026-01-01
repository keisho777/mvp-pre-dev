FROM ruby:3.3.10 AS builder
ENV LANG C.UTF-8
ENV TZ Asia/Tokyo

# 作業ディレクトリを作成
RUN mkdir /app
WORKDIR /app

# Node.js と Yarn のリポジトリ追加
RUN apt-get update -qq \
&& apt-get install -y ca-certificates curl gnupg \
&& mkdir -p /etc/apt/keyrings \
&& curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
&& NODE_MAJOR=20 \
&& echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
# && wget --quiet -O - /tmp/pubkey.gpg https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
# && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
&& curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /etc/apt/keyrings/yarn.gpg \
&& echo "deb [signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

# 必要なパッケージをインストール
RUN apt-get update -qq \
&& apt-get install -y build-essential libpq-dev nodejs yarn vim \
&& rm -rf /var/lib/apt/lists/*

# Bundler をインストール
RUN gem install bundler

# Gemfile だけを先にコピー（キャッシュ最適化）
COPY Gemfile Gemfile.lock ./

# Gem をインストール（Gemfile が変わらない限りキャッシュが効く）
RUN bundle install

# アプリのコードをコピー（最後に実行）
COPY . /app

RUN bundle exec rails assets:precompile

# FROM ruby:3.3.10 AS development
# WORKDIR /app
# COPY --from=builder /app /app


FROM ruby:3.3.10 AS production

ENV RAILS_ENV=production

WORKDIR /app

RUN apt-get update -qq \
&& apt-get install -y libpq5 \
&& rm -rf /var/lib/apt/lists/*

# アプリと gem をコピー
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /app /app
COPY Gemfile Gemfile.lock ./

# 本番用設定
RUN bundle config set without 'development test'

CMD ["bundle", "exec", "rails", "db:migrate", "bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
