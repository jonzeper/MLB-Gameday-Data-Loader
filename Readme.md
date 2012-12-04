Leagues
-------
mlb - Baseball!
aaa - AAA
aax - AA
afa - Advanced A
afx - A
asx - Short-season A
rok - Rookie

Files we care about
-------------------

	batters/
	pitchers/
		#playerid#.xml
			team
			id
			position
			first_name
			last_name
			height
			weight
			dob
			bats
			throws

	inning/
		inning_#.xml
			series of atbat items, with brief info on each pitch (Ball, Strike, Foul)

		inning_hit.xml
			info about ball hit in play - includes xy locations

		inning_Scores.xml
			only useful for realtime gameday feed

	pbp/
		This contains detailed info about each atbat including result and xy for each pitch
		I guess we only need to get the pitchers folder here since they'll have the same info in each folder?

		Used from 2006-2007. Afterwards, pitchfx data is in the inning files

		batters/
		pitchers/

	game.xml
		The only thing I see here which isn't in linescore.xml is the City, ST where the game is played

	linescore.xml
		Some more info about the game - includes team nicknames

	players.xml
		I don't think this has anything useful for us, but let's grab it anyway
		since it's a nice compact list of the the players in the game

	bench.xml
	benchO.xml
	boxscore.xml
	gamecenter.xml
	gameday_Syn.xml
	miniscoreboard.xml
	plays.xml
		These files are used by the gameday player, but don't really have anything useful for us	

