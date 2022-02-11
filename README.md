# potentual
A small tool to recommend who to follow based on your Twitter mutuals and who's following you

## The goal, and how it works
The problem is a simple cyclic graph that looks like this:

![potentual cycle](https://github.com/kokoscript/potentual/blob/main/potentualCycle.png?raw=true)

Where circles are users, arrows are following relationships, and the red arrow is what we're trying to find. In other words, who follows you *and* is also followed by one or more of your mutuals?

The solving process looks like this:
- Get all the followers of the starting user as well as who they're following
- Figure out who the starting user's mutuals are (both following and followed by)
- Get all mutuals' following lists
- Connect the dots: For each person who is following the starting user, is there a mutual that follows them as well? If so, recommend them

## Prerequisites
- Haxe
- twurl
- Access to the Twitter API from the account you want recommendations for
- Patience! (see "Limitations")

I planned to get rid of the twurl and developer account requirements by making use of basic HTTP requests, but I didn't really want to dive into figuring out OAuth. Plus, Twitter's wording on per-app rate limits is a bit confusing, so to me it seems like any user of potentual would have to use a shared rate limit... not good!

## Building
- `haxe build.hxml` to build
- `./out/Potentual` to run

## Limitations
Thanks to Twitter, there's a pretty hard limit on how many times one can do a follower/following lookup; currently, it's 15 lookups every 15 minutes for both endpoints. Since you can only get 1000 users at a time, this limit is very easy to hit if you have many followers, as well as if you have mutuals who follow many people. Even if one of your mutuals follows less than 1000 people, that's still a full request. Potentual will give an estimated time to make all these requests before it starts getting who your mutuals follow.

Potentual doesn't check the remaining lookups available when it starts running, and assumes it has the full 15 for each endpoint and keeps track on its own. So if it fails for whatever reason (sometimes twurl gets a bit tripped up), you'll need to wait a full 15 minutes before trying again- otherwise it'll just crash. This is probably an easy fix, but since I don't expect many people to use this, it's not really a priority for me.

Also, potentual doesn't find users in *exactly* the right way I wanted it to. Initially I wanted it to ensure the recommended accounts were also mutuals with a mutual of yours, however due to the API limits, this would be a showstopper on any account with a substantial number of followers. Luckily this behavior is actually a subset of what's generated, and usually the recommended accounts are mutuals with one of your mutuals anyway, so it's not a big deal.

I also wanted to turn this into a web app but the rate limits made me reconsider lol

## Runtime complexity?
Very
