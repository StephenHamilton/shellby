# Shellby

Shellby is an IRC bot built mostly in bash script. This allows you to write handlers that work on the IRC input as a stream, with stdout being sent to the IRC server.

# Motivation

> Yeah, yeah, but your [developers] were so preoccupied with whether or not they could that they didn't stop to think if they should.
>
> Dr. Ian Malcolm

# Usage

Configure `~/.shellby/etc/config` with appropriate values then run `bin/shellby`.

If you register the account for the bot you can add a `~/.shellby/etc/password` file containing just the nickserv password and it will auth itself on join.

## Dependencies

* ncat (provided by nmap)
* dos2unix
* gawk 
* bash >=4

## Data

The files for the gh command are not included in the repository. I have compiled a list of submissions for use with the bot, but I do not believe that I am allowed to redistribute said content. Email me if you would like a copy.
