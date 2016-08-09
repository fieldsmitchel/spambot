module spambot_util;

import std.json,
std.stdio,
std.algorithm,
std.string;

//TODO: alias Message as Message.text to simplify code operating on Message.text
struct Message
{
	string user;
	string text;
	string tags;
	//string time;
}

Message* stringToMessage(string rawmessage)
{
	Message* newMessage;
	//debug.writeln(format("String to message: %s",rawmessage));
	if(canFind(rawmessage,"PRIVMSG"))
	{
		//all user messages start with a tag string that begins with @
		if(rawmessage[0] == '@')
		{
			//countUntil returns the index of the space so the username is 2 indexes farther in
			auto tagend = countUntil(rawmessage,' ')+2;
			//new Message(username,message,tags)
			newMessage = new Message(rawmessage[tagend..countUntil(rawmessage,'!')],
									 //index of username + distance from there to the colon + 1 is where the message starts
									 rawmessage[(tagend + countUntil(rawmessage[tagend..$],':') + 1)..$],
									 //tagend includes an extraneous space and colon
									 rawmessage[0..(tagend-2)]);
			if(canFind(newMessage.text,'\x01'))
			{
				//messages that start with /me are formatted as \x01ACTION message\x01 where \x01 is a single unicode char
				//thus starting at the ninth character starts where the actual message begins
				newMessage.text = "/me " ~ newMessage.text[8..($-1)];
			}
		}
		//else it's a twitchnotify system PRIVMSG
		else
		{
			newMessage = new Message(rawmessage[(countUntil(rawmessage[1..$],':')+1)..$],
									 rawmessage[0..countUntil(rawmessage,'!')]);
		}
	}
	else
	{
		return null;
	}
	return newMessage;
}

//save JSONValue to file
void saveJSON(ref JSONValue jsonval, immutable string file)
{
	//open the file for write (erases current data and overwrites it)
	auto f = File(file,"w");

	f.write(toJSON(&jsonval,true));

	f.close();
}

//formatOutgoingMessage takes a string message and returns the full irc message to be sent
string formatOutgoingMessage(string channel, string message)
{
	return format("PRIVMSG #%s :%s\r\n",channel,message);
}