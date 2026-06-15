return {
	Name = "give";
	Aliases = {};
	Description = "Gives a player";
	Group = "Admin";
	Args = {
		{
			Type = "player";
			Name = "plr";
			Description = "Playername";
		},
		{
			Type = "tool";
			Name = "text";
			Description = "Tool";
		},
	};
}