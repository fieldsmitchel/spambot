#Synopsis

spambot is a Twitch.tv chatbot for channel administration and chat interaction written in the D programming language as a way to explore the features of D, implement multithreading in a and experiment with the Twitch IRC and HTTP APIs. The name of the bot comes from an inside joke in the Twitch communities I am a part of.

####Blacklist Format

The blacklist.json file holds pairs of blacklisted phrases and the moderation responses in the format "phrase":"response". Blacklist phrases are treated as raw strings with the only special cases being * at the beginning or end of the string. Blacklist elements beginning and ending with * can appear anywhere in the message (ex. *hell* matches both hello and shell). Blacklist elements beginning with * do not include words that start with the blacklist element (ex. *hell doesn't match hello but will match shell). Blacklist elements ending with * do not include words that end with the blacklist element (ex. hell* does match hello but will not match shell). Blacklist elements with no * only moderate messages with the EXACT word (ex. hell does not match either hello or shell).

##Installation

Currently, the only way to get the bot is to compile the source manually, as it is still largely in flux.

##License

Copyright (C) 2016  Mitchel Fields

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License for more details.