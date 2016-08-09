module http_handler;

import globals,
std.stdio,
std.exception,
std.algorithm,
std.file,
std.net.curl,
std.format,
std.json;

//TODO: check for new followers!

void httptest()
{
	try
	{
		JSONValue viewers = parseJSON(getChatList());
		writeln(viewers["chatters"]);
		JSONValue followers = parseJSON(sendAPIRequest(format("channels/%s/follows",CHAN)));
		writeln(followers);
	}
	catch(Exception e)
	{
		writeln("ERROR: Is Twitch down right now?");
	}
}

char[] getChatList()
{
	return get(format("tmi.twitch.tv/group/user/%s/chatters",CHAN));
}

//TODO: if necessary add POST, PUT, and DELETE???
char[] sendAPIRequest(immutable string endpoint)
{
	return get(format("https://api.twitch.tv/kraken/%s?oauth_token=%s",endpoint,PASS[(countUntil(PASS,":")+1)..$]));
}