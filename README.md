# daily_book

get quotes from free ebooks for your friends.

## description

quote.pl is a perl script which searches free ebooks at [project gutenberg][gutenberg] for an english formatted quote, which fits inside 140 characters, then tweets it.

## setup

to post to twitter, you'll need to create oauth credentials at [https://apps.twitter.com][twitter]

quote.pl will look for those credentials in a file named .quote.rc, inside the pwd

```
# quote.pl twitter oauth settings
account:_daily_book
consumer_key:QWERTY1234
consumer_secret:FEEDBEEF
access_token:12345-SOMETHING
access_token_secret:anotherlongstringnotreallyanaccesstoken
```
warning: ^ not really oauth credentials ^

## usage

```
$ perl quote.pl -h
usage: ./quote.pl -s -t

options:
	-t|--twitter		post the quote to twitter

	-s|--silent		    dont display any output (requires -t)

	-m|--manual 1234	manually specify the book number

	-h|--help		    displays this dialogue
```

quote.pl can be run without any options, and will simply go out and get a quote, then show it to you.

```
$ perl quote.pl
quote.pl

finding a quote, just a moment
for more information, please see quote.log

title: Girl Scouts at Dandelion Camp 
author: Lillian Elizabeth Roy 

"Scouts, don't give up," called Mrs. Vernon, laughingly. "Betty is doing fine, so you must not stop such treatment." gutenberg.org/ebooks/37800

```

you can also manually specify an ebook number from gutenberg's catalog, quote.pl will tell you if it couldn't find a book with that number.

if you want to run the script via cron, there is also a silent mode, which won't output anything but the log file.

quote.log contains issues found during the run, as well as why it skips over a book.

```
$ cat quote.log 
[05052016.103329] [info] no quote found - 7718.txt
[05052016.104014] [info] no quote found - 36304.txt
[05052016.104027] [info] posting to twitter
[05052016.104048] [info] ebook isn't in English - 12637.txt
[05052016.104048] [info] posting to twitter
[05052016.104219] [info] posting to twitter
[05052016.205719] [fatal] cannot open index: Permission denied
[05052016.210324] [info] no quote found - 29493.txt
[05052016.210324] [info] posting to twitter
```

## unlicense

This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <http://unlicense.org>

[gutenberg]: http://www.gutenberg.org/wiki/Main_Page
[twitter]: https://apps.twitter.com
