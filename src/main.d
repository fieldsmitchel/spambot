module main;

import message_handler, globals, memes, synchronizedQueue;
import std.socket, std.stdio, std.format, std.algorithm, std.concurrency, std.file, std.json, std.string, std.math;
import core.stdc.stdlib, core.time, core.thread;

void main()
{
//label to return to if the configuration is invalid
init:
	//version(none)
	botInit();
	//httptest();

	//auto addr = getAddress(HOST,PORT)[0];
	auto sock = new Socket(AddressFamily.INET,SocketType.STREAM);

	sock.connect(getAddress(HOST,PORT)[0]);
	sock.send(format("PASS %s\r\n",PASS));
	sock.send(format("NICK %s\r\n",NICK));
	//request message tag information (see: https://github.com/justintv/Twitch-API/blob/master/IRC.md)
	sock.send("CAP REQ :twitch.tv/tags\r\n");
	sock.send(format("JOIN #%s\r\n",CHAN));

	auto buffer = new char[2048];
	buffer[0] = '\r';

	//this loop catches the initial twitch irc responses about logging in successfully and entering the channel that aren't useful for the end user
	while(buffer[1..21] != "dumj0p.tmi.twitch.tv")
	{
		sock.receive(buffer);

		debug.writeln(buffer[0..countUntil(buffer,'\r')]);

		//if the username or oauth are incorrect
		if(canFind(buffer,"Login unsuccessful"))
		{
			stderr.writeln("ERROR: Login unsuccessful. Please doublecheck that all fields are filled correctly.");
			goto init;
		}
	}

	auto messageQueue = new shared SynchronizedQueue!string();
	auto responseQueue = new shared SynchronizedQueue!string();

	auto messenger = spawnLinked(&messageHandler,thisTid,messageQueue,responseQueue);

	//when main goes out of scope
	scope(exit)
	{
		debug.writeln("main exiting scope");
		debug.writeln("sending exit message to messenger");
		//pass a priority message to the messenger telling it to shutdown
		prioritySend(messenger,1);
		//wait for a response signaling the child thread has terminated before shutting down
		receive(
				(int message)
				{
					//if the response was invalid throw an Exception
					if(message != 1)
					{
						throw new Exception("Oops! Something went horribly awry during shutdown!");
					}
				});
		if(SHOW_SALUTATIONS)
		{
			sock.send(message_handler.formatOutgoingMessage(SHUTDOWN));
		}
		sock.close();
		debug.writeln("main complete");
	}

	sock.blocking(false);
	if(SHOW_SALUTATIONS)
	{
		sock.send(message_handler.formatOutgoingMessage(STARTUP));
	}
	auto lastresponse = MonoTime.currTime();

	while(true)
	{
		//switch based on the status of the irc receive
		switch(sock.receive(buffer))
		{
			//if receive returned 0 the bot has been disconnected
			case 0:
				//write to the debug out that the bot disconnected and goto the disconnected label
				debug.writeln("Disconnected from server");
				goto disconnected;
			case -1:
				break;
			default:

				//if the new message was a server PING send a PONG
				if(buffer[0..4] == "PING")
				{
					debug.writeln("PING (main)");
					sock.send("PONG :tmi.twitch.tv\r\n");
					debug.writeln("PONG (main)");
				}
				//else if the message was the bot admin's !exit command shut down the bot
				else if(canFind(buffer,'!') && //canFind(buffer,' ') &&
						buffer[(countUntil(buffer,':')+1)..countUntil(buffer,'!')] == OWNER &&
						buffer[(countUntil(buffer,'\r')-5)..countUntil(buffer,'\r')] == "!exit")
				{
					return;
				}
				//else send the new message (the buffer from 0 until the carriage return) to the message handler
				else
				{
					//every irc message ends with '\r' so that is the final character of the newest message in the buffer
					//anything past '\r' will be leftover from previous messages
					string message = cast(string)(buffer[0..countUntil(buffer,'\r')].dup);
					messageQueue.enqueue(message);
				}
		}

		//if there is a response in the response queue and the last response was greater than 2/3 of a second ago (to avoid being globalled)
		if(responseQueue.length() > 0 &&
		   (MonoTime.currTime() - lastresponse).total!"seconds" > 0.7)
		{
			//send the first response in the queue and update the time of the last message sent
			//sock.send(responseQueue.dequeue());
			debug.writeln(responseQueue.dequeue());
			while(!(sock.send("PRIVMSG #dumj01 :This should send after every chat message OMGScoots\r\n") > 0))
			{}
			lastresponse = MonoTime.currTime();
		}
	}
//label for when the bot is unexpectedly disconnected
disconnected:
	//before the program terminates, wait for the user to press enter (this could be adapted to add commands like reboot)
	readln();
}

void botInit()
{
	writeln("BOT STARTING!\n");

	if(!exists("irc.conf"))
	{
		auto f = File("irc.conf","w");
		f.write("{\n" ~
					"\t\"OWNER\": \"\",\n" ~
					"\t\"NICK\": \"\",\n" ~
					"\t\"PASS\": \"\",\n" ~
					"\t\"CHAN\": \"\",\n" ~
					"\t\"SHOW_OPTIONS\": true,\n" ~
					"\t\"SALUTATIONS\":\n" ~
					"\t{\n" ~
						"\t\t\"STARTUP\":\"Bot starting\",\n" ~
						"\t\t\"SHUTDOWN\":\"Bot shutting down\"\n" ~
					"\t},\n" ~
					"\t\"SHOW_SALUTATIONS\":false\n" ~
				"}");
	}

	auto filecontents = readText("irc.conf");

	JSONValue config = parseJSON(filecontents);
	OWNER = config["OWNER"].str();
	NICK = config["NICK"].str();
	PASS = config["PASS"].str();
	CHAN = config["CHAN"].str();
	STARTUP = config["SALUTATIONS"]["STARTUP"].str();
	SHUTDOWN = config["SALUTATIONS"]["SHUTDOWN"].str();
	if(config["SHOW_OPTIONS"].type() == JSON_TYPE.TRUE)
	{
		SHOW_OPTIONS = true;
	}
	else
	{
		SHOW_OPTIONS = false;
	}

	if(config["SHOW_SALUTATIONS"].type() == JSON_TYPE.TRUE)
	{
		SHOW_SALUTATIONS = true;
	}
	else
	{
		SHOW_SALUTATIONS = false;
	}

	if(!SHOW_OPTIONS)
	{
		return;
	}
	//string listing current settings and asking the user whether they should be edited
	immutable(char)[] initmenu;
	string input;

	//label to return to if editing is canceled
init:
	initmenu = format("This bot will be chatting as: %s\n" ~
					  "This bot will be chatting in the channel: %s\n" ~
					  "The administrator for the bot is %s\n" ~
					  "Would you like to edit these settings? [Y/n]\n" ~
					  "(To disable this message, change SHOW_OPTIONS to false in irc.conf)",
					  NICK,
					  CHAN,
					  OWNER);
	
	writeln(initmenu);
	input = readln();

	//check that the input is valid (either Y,y,N, or n)
	//this can definitely be simplified but it works the way it is
	while(input.length > 2 || (input[0] != 'y' && input[0] != 'Y' && input[0] != 'n' && input[0] != 'N'))
	{
		stderr.writeln("ERROR: Invalid input.");
		writeln(initmenu);
		input = readln();
	}

	//if the input was Y or y show the field edit menu otherwise continue starting the bot
	if(input[0] == 'y' || input[0] == 'Y')
	{
		//track if the config has changed and should be saved
		bool configChanged = false;

		//string listing the current values of editable fields
		immutable(char)[] fields;

		//create temp variables for the fields to propogate edits without loosing the original values
		auto tempCHAN = CHAN, tempNICK = NICK, tempPASS = PASS, tempOWNER = OWNER;

	//label to return to after editing a field
	editfields:
		fields = format("Choose a field to edit:\n" ~
						"1. Channel:     %s\n" ~
						"2. Username:    %s\n" ~
						"3. Owner:       %s\n" ~
						"4. Save changes and return\n" ~
						"5. Cancel changes and return",
						tempCHAN,
						tempNICK,
						tempOWNER);

		writeln(fields);
		input = readln();

		//loop until the input is a valid character ('1','2', or '3')
		while(input.length > 2 || input[0] < '1' || input[0] > '5')
		{
			stderr.writeln("ERROR: Invalid input.");
			writeln(fields);
			input = readln();
		}

//TODO: validate field edits to insure they are valid

		//switch based on the character the user input
		switch(input[0])
		{
			//1. Channel
			case '1':
				writeln("What channel should be bot chat in?");
				//convert channel name to lower case and prepend # to fit the twitch irc message formatting (see: https://github.com/justintv/Twitch-API/blob/master/IRC.md)
				tempCHAN = toLower(strip(readln()));
				writeln(format("Bot is now configured to join channel: %s",tempCHAN));
				configChanged = true;
				goto editfields;

			//2. Username
			case '2':
				writeln("What is the bot's new username?");
				//convert the username to lower case
				tempNICK = toLower(strip(readln()));
				//logging into the twitch irc requires a valid oauth token starting with "oauth:" (see link above)
				writeln("What is the oath token for this username? (http://www.twitchapps.com/tmi/)");
				write("oauth:");
				tempPASS = "oauth:" ~ toLower(strip(readln()));
				writeln(format("Bot is now configured to use the username: %s",tempNICK));
				configChanged = true;
				goto editfields;

			//3. Owner
			case '3':
				writeln("What is the username of the new administrator?");
				tempOWNER = toLower(strip(readln()));
				writeln(format("Bot administrator is now: %s\n",tempOWNER));
				configChanged=true;
				goto editfields;

			//4. Save changes and return
			case '4':
				writeln("Saving configuration changes");
				config["OWNER"] = OWNER = tempOWNER;
				config["NICK"] = NICK = tempNICK;
				config["PASS"] = PASS = tempPASS;
				config["CHAN"] = CHAN = tempCHAN;
				config["SHOW_OPTIONS"] = SHOW_OPTIONS;
				saveConfig(config);
				goto init;

			//5. Cancel changes and return
			case '5':
				goto init;

			//seriously, if the code ever ends up here, I don't even know what could have gone wrong
			default:
				stderr.writeln("Error: If you are seeing this something has gone very wrong");
				exit(1);
		}
	}

}

//save configuration changes to ircco.nf
void saveConfig(ref JSONValue config)
{
	//open the file for write (erases current data and overwrites it)
	auto f = File("ircco.nf","w");

	//std.json doesn't format JSONValues to be human readable so take the values and add the newlines and brackets to either end before splitting the values on the comma delimiters
	//this works because commas are illegal characters for all of the fields
	auto json = splitter("{\n\t" ~ config.toString()[1..($-1)] ~ "\n}",",");
	//then join the strings back together with ",\n\t" between them
	f.write(json.join(",\n\t"));

	f.close();
}