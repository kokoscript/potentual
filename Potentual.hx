import haxe.Json;
import sys.io.Process;
import haxe.ds.ArraySort;

class Potentual {
	static var USER:String; 										// User to start the follow maps from (aka, your handle)
																	// this used to be a constant, hence the capitalization, but now we just pull from /user/me
	static var handleNameMap:Map<String, String>; 					// Mapping of user handles to display names
	static var handleIdMap:Map<String, String>; 					// Mapping of user handles to IDs (only following)
	static var followers:Array<String>; 							// List of users following the starting user
	static var followingMap:Map<String, Array<String>>; 			// Key: user, value: array of users the key follows
	static var mutualList:Array<String>;							// List of users the starting user both follows and is followed by
	static var recommends:Map<String, Array<String>>;				// Key: recommended user, value: mutuals they're followed by
	static var recommendsCounts:Array<{user:String, count:Int}>;	// Array of structs containing counts of recommendations for sorting

	// for keeping track of how many requests we make so we don't crash into the rate limit
	static var followerRequestCount:Int = 0;
	static var followingRequestCount:Int = 0;

	public static function main():Void {
		handleNameMap = new Map<String, String>();
		handleIdMap = new Map<String, String>();
		followers = new Array<String>();
		followingMap = new Map<String, Array<String>>();
		mutualList = new Array<String>();
		recommends = new Map<String, Array<String>>();
		recommendsCounts = new Array<{user:String, count:Int}>();

		var userData:Dynamic = runTwurl("/2/users/me");
		USER = userData.data.username;
		handleIdMap.set(USER, userData.data.id);
		Sys.println("Getting follow map for @" + USER + " (ID " + handleIdMap.get(USER) + ")");

		Sys.println("Gathering followers...");
		followers = getFollowersOfUser(handleIdMap.get(USER));
		trace(followers);
		Sys.println("Gathering following...");
		followingMap.set(USER, getFollowingOfUser(handleIdMap.get(USER)));
		trace(followingMap.get(USER));

		Sys.println("Determining mutuals...");
		mutualList = getMutuals();
		Sys.println("here they are :) --> " + mutualList);

		Sys.println("Getting mutuals' followings...");
		printLookupEta();
		for (mutual in mutualList) {
			followingMap.set(mutual, getFollowingOfUser(handleIdMap.get(mutual)));
		}

		Sys.println("Generating recommendations...");
		findRecommendations();
		Sys.println("Cleaning and sorting...");
		// Cleaning (remove already existing mutuals)
		for (user in recommends.keys()) {
			if (mutualList.contains(user)) {
				recommends.remove(user);
			}
		}
		// Sorting
		for (user in recommends.keys()) {
			recommendsCounts.push({user: user, count: recommends.get(user).length});
		}
		ArraySort.sort(recommendsCounts, function(a, b):Int {
			if (a.count < b.count) return 1;
			else if (a.count > b.count) return -1;
			else return 0;
		});
		// Print in the order of count sort
		for (user in recommendsCounts) {
			Sys.println(handleNameMap.get(user.user) + " (@" + user.user + ") - followed by " + recommends.get(user.user));
		}
	}

	// Runs twurl and returns the resulting JSON object
	public static function runTwurl(endpoint:String):Dynamic {
		var twurl:Process = new Process("twurl \'" + endpoint + "\'");	// singlequotes to prevent shell interpretation of the endpoint
		trace("Call twurl: " + endpoint);
		var json:Dynamic = Json.parse(twurl.stdout.readLine());
		twurl.close();
		trace("Result: " + json);
		return json;
	}

	// Returns a list of all users that are following the specified user, based on ID
	public static function getFollowersOfUser(id:String):Array<String> {
		var followerList:Array<String> = new Array<String>();
		var json:Dynamic;
		var users:{data:Array<Dynamic>, meta:Dynamic};
		var next_token:String = null;

		do {
			// Prevent going past the rate limit
			if (followerRequestCount == 15) {
				Sys.println("Hit rate limit, please wait 15 minutes. (blame twitter)");
				Sys.sleep((15 * 60) + 5); // extra few seconds just in case
				followerRequestCount = 0;
			}

			json = runTwurl("/2/users/" + id + "/followers?max_results=1000" + (next_token != null ? ("&pagination_token=" + next_token) : ""));
			followerRequestCount++;
			users = json;

			for (user in users.data) {
				followerList.push(user.username);
				handleNameMap.set(user.username, user.name);
				handleIdMap.set(user.username, user.id);
			}

			next_token = json.meta.next_token;
		} while (json.meta.next_token != null);

		return followerList;
	}

	// Returns a list of all users that the user is following, based on ID
	public static function getFollowingOfUser(id:String):Array<String> {
		var followingList:Array<String> = new Array<String>();
		var json:Dynamic;
		var users:{data:Array<Dynamic>, meta:Dynamic};
		var next_token:String = null;

		do {
			// Prevent going past the rate limit
			if (followingRequestCount == 15) {
				Sys.println("Hit rate limit, please wait 15 minutes. (blame twitter)");
				Sys.sleep((15 * 60) + 5); // extra few seconds just in case
				followingRequestCount = 0;
			}

			json = runTwurl("/2/users/" + id + "/following?max_results=1000" + (next_token != null ? ("&pagination_token=" + next_token) : ""));
			followingRequestCount++;
			users = json;

			for (user in users.data) {
				followingList.push(user.username);
				handleNameMap.set(user.username, user.name);
				handleIdMap.set(user.username, user.id);
			}

			next_token = json.meta.next_token;
		} while (json.meta.next_token != null);

		return followingList;
	}

	public static function getFollowingCountOfUser(uname:String):Int {
		var json:Dynamic = runTwurl("/2/users/by/username/" + uname + "?user.fields=public_metrics");
		return Std.parseInt(json.data.public_metrics.following_count);
	}

	// Get estimated time to look up who each mutual is following, in minutes
	public static function printLookupEta():Void {
		var totalLookups:Int = 0;
		var mutualFollowingCounts:Array<Int> = new Array<Int>();
		for (mutual in mutualList) {
			mutualFollowingCounts.push(getFollowingCountOfUser(mutual));
			Sys.println(mutual + ": " + mutualFollowingCounts[mutualFollowingCounts.length - 1]);
		}

		for (entry in mutualFollowingCounts) {
			totalLookups++;
			while (entry > 1000) {
				totalLookups++;
				entry -= 1000;
			} 
		}

		Sys.println("ETA: " + (Std.int(((totalLookups + followingRequestCount) / 15)) * 15) + " minutes");
	}

	// Determines who's mutuals with the starting user.
	public static function getMutuals():Array<String> {
		var mutualList:Array<String> = new Array<String>();
		for (user in followers) {
			if (followingMap.get(USER).contains(user)) {
				mutualList.push(user);
			}
		}
		return mutualList;
	}

	// the guy
	public static function findRecommendations():Void {
		for (mutual in mutualList) {
			trace("check mutual " + mutual);
			for (user in followers) {
				if (followingMap.get(mutual).contains(user)) {
					trace("found match: " + user);
					if (!recommends.exists(user)) {
						recommends.set(user, new Array<String>());
					}
					recommends.get(user).push(mutual);
				}
			}
		}
	}
}