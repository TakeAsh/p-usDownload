# Ustream Archive Downloader

## usage

1. Edit a config file.
```
username: your_name
password: your_password
channels:
  - your_channel1
  - your_channel2
  - your_channelN
```
1. Launch script with the config file name.
```
usDownload.pl [config.yml]
```
1. The script start download and make directries for each channels.
1. The script make two files for each channels in the directory.
  * ChannelName.rss - The informations of video files within the channel
  * ChannelName.log - The download results

## attention

* This script can download your own videos.
* This script make directries under current directry, so you need a write permission of current directory.

## link

* [Ustream Asia / Japan サポートブログ: アーカイブ映像の一括ダウンロード方法](http://blog.ustream-asia.jp/2014/09/blog-post_68.html)
