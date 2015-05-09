# -*- coding: utf-8 -*-

#
# waiting-chojugiga
#
# 鳥獣戯画展の公式Twitterアカウントの発言から、
# 待ち時間の情報を収集する。
#
#
# 使い方
# =====
#
# Twitterアプリの登録をして、secrets.jsonにconsumer_key等を書いておくこと。
# 続いて以下のコマンドを実行すると、最新の200ツイートを取得してcsvに結果を吐き出す。
#
# $ ruby crawl.rb
#
# 更に過去or最新のツイートを取得するときは、上のコマンドを再実行する。
# 取得済みのツイートは無視して200ツイート取得する。
#
#
# 依存ライブラリ
# ==============
#
# 以下のgemを使用します。
#
# * twitter
# * json
# * csv
# * time
#
#
# ライセンス
# ==========
#
# MIT
#
#

require 'twitter'
require 'time'
require 'csv'
require 'json'

TW_ACCOUNT = 'chojugiga_ueno'
TWEETS = 'tweets.csv'
REPORT = 'report.csv'
SECRETS = 'secrets.json'

re_enter = /待ち時間.*?約(\d+)分(待ち)?/
re_enter2 = /待ち時間.*?入場待ち.*?約(\d+)分/
re_enter3 = /会場へは並ばずに|待ち時間はなくなり/
re_kou   = /甲巻約(\d+)分/
re_otsuheitei = /乙.*?丙.*?丁巻.*?(\d+)分(待ち)?/
re_otsuheitei2 = /乙.*?丙.*?丁巻.*?待ち時間なし/
re_time  = /(\(|（)(\d+[^0-9]\d+)現在(\)|）)/

secrets = open(SECRETS) do |io|
  JSON.load(io)
end

client = Twitter::REST::Client.new do |config|
  config.consumer_key        = secrets['consumer_key']
  config.consumer_secret     = secrets['consumer_secret']
  config.access_token        = secrets['access_token']
  config.access_token_secret = secrets['access_token_secret']
end

tweets = []
latest_id = 0 
oldest_id = 0

if FileTest.exist?(TWEETS) then
  CSV.open(TWEETS, 'r+') do |csv|
    # tweet: id, text, created_at
    csv.each do |row|
      tweets << [row[0].to_i, row[1], Time.parse(row[2]).localtime]
    end
  end

  tweets = tweets.sort_by{|rec| rec[0] }.uniq{|rec| rec[0] }
  
  latest_id = tweets.last[0]
  oldest_id = tweets.first[0]
end

opt = {
  count: 200,
  exclude_replies: true,
  include_rts: false
}

tweets_tl =
  client.user_timeline(
                       TW_ACCOUNT, 
                       latest_id != 0 ? opt.merge( {since_id: latest_id} ) : opt) +
  client.user_timeline(
                       TW_ACCOUNT, 
                       oldest_id != 0 ? opt.merge( {max_id: oldest_id} ) : opt)

tweets_tl.each do |tweet|
  tweets << [tweet.id, tweet.text, tweet.created_at.getlocal]
end

tweets = tweets.sort_by{|rec| rec[0] }.uniq{|rec| rec[0] }

records = []

tweets.each do |tweet|
  # tweet: id, text, created_at
  wait_enter = -1
  wait_kou = 0
  wait_otsu = 0
  report_time = ''
  tweet_time = ''

  tw_id = tweet[0]
  text = tweet[1]
  created_at = tweet[2]
  
  if text =~ re_enter or text =~ re_enter2 then
    wait_enter = $1.to_i
  elsif text =~ re_enter3 then
    wait_enter = 0
  end

  # 待ち時間告知とは無関係のツイートなら無視する
  next if wait_enter < 0

  if text =~ re_kou then
    wait_kou = $1.to_i
  end
  if text =~ re_otsuheitei then
    wait_otsu = $1.to_i
  end
  if text =~ re_otsuheitei2 then
    wait_otsu = 0
  end
  if text =~ re_time then
    report_time = ($2 ? created_at.strftime('%Y-%m-%d ') + $2
                   : created_at.strftime('%Y-%m-%d %H:%M'))
  else
    report_time = created_at.strftime('%Y-%m-%d %H:%M')
  end
  tweet_time = created_at.strftime('%Y-%m-%d %H:%M')

  records << [tw_id, wait_enter, wait_kou, wait_otsu, report_time, tweet_time]
end

CSV.open(TWEETS, 'w+') do |csv|
  # tweet: id, text, created_at
  tweets.each do |tw|
    csv << [tw[0], tw[1], tw[2].getlocal]
  end
end

records = records.sort_by{|rec| rec[0] }.uniq{|rec| rec[0] }

CSV.open(REPORT, 'w+:cp932') do |csv|
  # id, 入場待ち, 甲巻待ち, 乙丙丁巻待ち, 調査時刻, tweet時刻
  csv << ['ID', '入場待ち', '甲巻待ち', '乙丙丁巻待ち', '調査時刻', 'tweet時刻']
  records.each do |row|
    csv << row
  end
end
