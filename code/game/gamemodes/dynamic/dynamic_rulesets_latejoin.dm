//////////////////////////////////////////////
//                                          //
//            LATEJOIN RULESETS             //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/latejoin/trim_candidates()
	for(var/mob/P in candidates)
		if(!P.client || !P.mind || !P.mind.assigned_role) // Are they connected?
			candidates.Remove(P)
		else if(!mode.check_age(P.client, minimum_required_age))
			candidates.Remove(P)
		else if(P.mind.assigned_role in restricted_roles) // Does their job allow for it?
			candidates.Remove(P)
		else if((exclusive_roles.len > 0) && !(P.mind.assigned_role in exclusive_roles)) // Is the rule exclusive to their job?
			candidates.Remove(P)
		// BLUEMOON ADD START
		else if(!(P.client.prefs.toggles & MIDROUND_ANTAG)) // У игрока отключен преф "быть антагонистом посреди раунда"
			candidates.Remove(P)
		// BLUEMOON ADD END
		else if(antag_flag_override)
			if(!(HAS_ANTAG_PREF(P.client, antag_flag_override)))
				candidates.Remove(P)
		else
			if(!(HAS_ANTAG_PREF(P.client, antag_flag)))
				candidates.Remove(P)

/datum/dynamic_ruleset/latejoin/ready(forced = 0)
	if (!forced)
		var/job_check = 0
		if (enemy_roles.len > 0)
			for (var/mob/M in mode.current_players[CURRENT_LIVING_PLAYERS])
				if (M.stat == DEAD)
					continue // Dead players cannot count as opponents
				if (M.mind && (M.mind.assigned_role in enemy_roles) && (!(M in candidates) || (M.mind.assigned_role in restricted_roles)))
					job_check++ // Checking for "enemies" (such as sec officers). To be counters, they must either not be candidates to that rule, or have a job that restricts them from it

		var/threat = round(mode.threat_level/10)
		if (job_check < required_enemies[threat])
			SSblackbox.record_feedback("tally","dynamic",1,"Times rulesets rejected due to not enough enemy roles")
			return FALSE
	return ..()

/datum/dynamic_ruleset/latejoin/execute()
	var/mob/M = pick(candidates)
	assigned += M.mind
	M.mind.special_role = antag_flag
	M.mind.add_antag_datum(antag_datum)
	log_admin("[M.name] was made into a [name] by dynamic.")
	return TRUE

//////////////////////////////////////////////
//                                          //
//           INTEQ TRAITORS                 //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/latejoin/infiltrator
	name = "InteQ Infiltrator"
	antag_datum = /datum/antagonist/traitor
	antag_flag = "traitor late"
	antag_flag_override = ROLE_TRAITOR
	protected_roles = list("Expeditor", "Shaft Miner", "NanoTrasen Representative", "Internal Affairs Agent", "Blueshield", "Peacekeeper", "Brig Physician", "Security Officer", "Warden", "Detective", "Head of Security","Bridge Officer", "Captain", "Head of Personnel", "Quartermaster", "Chief Engineer", "Chief Medical Officer", "Research Director") //BLUEMOON CHANGES
	restricted_roles = list("AI", "Cyborg", "Positronic Brain")
	required_candidates = 1
	required_round_type = list(ROUNDTYPE_DYNAMIC_HARD, ROUNDTYPE_DYNAMIC_MEDIUM, ROUNDTYPE_DYNAMIC_LIGHT) // BLUEMOON ADD
	weight = 6  //BLUEMOON CHANGES
	cost = 6 //BLUEMOON CHANGES
	requirements = list(101,40,25,20,15,10,10,10,10,10)
	repeatable = TRUE

//////////////////////////////////////////////
//                                          //
//       REVOLUTIONARY PROVOCATEUR          //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/latejoin/provocateur
	name = "Provocateur"
	persistent = TRUE
	antag_datum = /datum/antagonist/rev/head
	antag_flag = "rev head late"
	antag_flag_override = ROLE_REV
	protected_roles = list("NanoTrasen Representative", "Internal Affairs Agent", "Blueshield", "Peacekeeper", "Brig Physician", "Security Officer", "Warden", "Detective", "Head of Security","Bridge Officer", "Captain", "Head of Personnel", "Quartermaster", "Chief Engineer", "Chief Medical Officer", "Research Director")  //BLUEMOON CHANGES
	restricted_roles = list("Cyborg", "AI", "Positronic Brain")
	enemy_roles = list("AI", "Cyborg", "Blueshield", "Peacekeeper", "Brig Physician", "Security Officer", "Warden", "Detective", "Head of Security","Bridge Officer", "Captain") //BLUEMOON CHANGES
	required_enemies = list(2,2,1,1,1,1,1,0,0,0)
	required_candidates = 1
	required_round_type = list(ROUNDTYPE_DYNAMIC_TEAMBASED, ROUNDTYPE_DYNAMIC_HARD, ROUNDTYPE_DYNAMIC_MEDIUM) // BLUEMOON ADD
	weight = 2
	delay = 1 MINUTES // Prevents rule start while head is offstation.
	cost = 7 //BLUEMOON CHANGES - маленький шанс и низкая стоимость из-за сложности
	requirements = list(101,101,101,101,50,20,20,20,20,20)
	flags = HIGH_IMPACT_RULESET
	blocking_rules = list(/datum/dynamic_ruleset/roundstart/revs)
	var/required_heads_of_staff = 3
	var/finished = FALSE
	/// How much threat should be injected when the revolution wins?
	var/revs_win_threat_injection = 20
	var/datum/team/revolution/revolution

/datum/dynamic_ruleset/latejoin/provocateur/ready(forced=FALSE)
	if (forced)
		required_heads_of_staff = 1
	if(!..())
		return FALSE
	var/head_check = 0
	for(var/mob/player in mode.current_players[CURRENT_LIVING_PLAYERS])
		if (player.mind.assigned_role in GLOB.command_positions)
			head_check++
	return (head_check >= required_heads_of_staff)

/datum/dynamic_ruleset/latejoin/provocateur/execute()
	var/mob/M = pick(candidates) // This should contain a single player, but in case.
	if(check_eligible(M.mind)) // Didnt die/run off z-level/get implanted since leaving shuttle.
		assigned += M.mind
		M.mind.special_role = antag_flag
		revolution = new()
		var/datum/antagonist/rev/head/new_head = new()
		new_head.give_flash = TRUE
		new_head.give_hud = TRUE
		new_head.remove_clumsy = TRUE
		new_head = M.mind.add_antag_datum(new_head, revolution)
		revolution.update_objectives()
		revolution.update_heads()
		SSshuttle.registerHostileEnvironment(revolution)
		return TRUE
	else
		log_game("DYNAMIC: [ruletype] [name] discarded [M.name] from head revolutionary due to ineligibility.")
		log_game("DYNAMIC: [ruletype] [name] failed to get any eligible headrevs. Refunding [cost] threat.")
		return FALSE

/datum/dynamic_ruleset/latejoin/provocateur/rule_process()
	var/winner = revolution.process_victory(revs_win_threat_injection)
	if (isnull(winner))
		return

	finished = winner
	return RULESET_STOP_PROCESSING

/// Checks for revhead loss conditions and other antag datums.
/datum/dynamic_ruleset/latejoin/provocateur/proc/check_eligible(datum/mind/M)
	var/turf/T = get_turf(M.current)
	if(!considered_afk(M) && considered_alive(M) && is_station_level(T.z) && !M.antag_datums?.len && !HAS_TRAIT(M, TRAIT_MINDSHIELD))
		return TRUE
	return FALSE

/datum/dynamic_ruleset/latejoin/provocateur/round_result()
	revolution.round_result(finished)

//////////////////////////////////////////////
//                                          //
//           HERETIC SMUGGLER               //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/latejoin/heretic_smuggler
	name = "Heretic Smuggler"
	antag_datum = /datum/antagonist/heretic
	antag_flag = "heretic late"
	antag_flag_override = ROLE_HERETIC
	protected_roles = list("Expeditor", "Shaft Miner", "NanoTrasen Representative", "Internal Affairs Agent", "Blueshield", "Peacekeeper", "Brig Physician", "Security Officer", "Warden", "Detective", "Head of Security","Bridge Officer", "Captain", "Prisoner", "Head of Personnel", "Quartermaster", "Chief Engineer", "Chief Medical Officer", "Research Director")  //BLUEMOON CHANGES
	restricted_roles = list("AI", "Cyborg", "Positronic Brain")  //BLUEMOON CHANGES
	required_round_type = list(ROUNDTYPE_DYNAMIC_HARD, ROUNDTYPE_DYNAMIC_MEDIUM) // BLUEMOON ADD; Существовал в тимбазе до удаления.
	required_candidates = 1
	weight = 4 //BLUEMOON CHANGES
	cost = 10
	requirements = list(101,101,101,50,40,20,20,15,10,10)
	repeatable = TRUE

//BLUEMOON ADD START - я добавляю это сюда вместо модулей, чтобы было удобно изменять параметры (для наглядности)
//////////////////////////////////////////////
//                                          //
//            SILENT CHANGELING             //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/latejoin/silent_changeling
	name = "Silent Changeling"
	antag_flag = "changeling late"
	antag_flag_override = ROLE_CHANGELING
	antag_datum = /datum/antagonist/changeling
	protected_roles = list("Expeditor", "Prisoner", "Shaft Miner", "NanoTrasen Representative", "Internal Affairs Agent", "Security Officer", "Blueshield", "Peacekeeper", "Brig Physician", "Warden", "Detective", "Head of Security","Bridge Officer", "Captain", "Head of Personnel", "Quartermaster", "Chief Engineer", "Chief Medical Officer", "Research Director")
	restricted_roles = list("AI", "Cyborg", "Positronic Brain")
	required_round_type = list(ROUNDTYPE_DYNAMIC_HARD, ROUNDTYPE_DYNAMIC_MEDIUM, ROUNDTYPE_DYNAMIC_LIGHT) // BLUEMOON ADD
	required_candidates = 1
	weight = 4
	cost = 10
	requirements = list(101,101,60,50,40,30,20,15,10,10)
	antag_cap = list("denominator" = 24)
	repeatable = TRUE

/datum/dynamic_ruleset/latejoin/silent_changeling/trim_candidates()
	. = ..()
	for(var/mob/P in candidates)
		if(HAS_TRAIT(P, TRAIT_ROBOTIC_ORGANISM)) // никаких роботов-вампиров из далекого космоса
			candidates -= P

//////////////////////////////////////////////
//                                          //
//            LATE BLOODSUCKERS             //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/latejoin/bloodsuckers
	name = "Bloodsucker Guest"
	antag_flag = "bloodsucker late"
	antag_flag_override = ROLE_BLOODSUCKER
	antag_datum = /datum/antagonist/bloodsucker
	protected_roles = list("Expeditor", "Prisoner", "Shaft Miner", "NanoTrasen Representative", "Internal Affairs Agent", "Security Officer", "Blueshield", "Peacekeeper", "Brig Physician", "Warden", "Detective", "Head of Security","Bridge Officer", "Captain", "Head of Personnel", "Quartermaster", "Chief Engineer", "Chief Medical Officer", "Research Director")
	restricted_roles = list("AI", "Cyborg", "Positronic Brain")
	enemy_roles = list("Blueshield", "Peacekeeper", "Brig Physician", "Security Officer", "Warden", "Detective", "Head of Security","Bridge Officer", "Captain") //BLUEMOON CHANGES
	required_enemies = list(2,2,1,1,1,1,1,0,0,0)
	required_candidates = 1
	required_round_type = list(ROUNDTYPE_DYNAMIC_LIGHT) // BLUEMOON ADD
	weight = 4
	cost = 5
	scaling_cost = 10
	requirements = list(101,101,60,50,40,30,20,15,10,10)
	antag_cap = list("denominator" = 39, "offset" = 1)
	repeatable = TRUE

/datum/dynamic_ruleset/latejoin/bloodsuckers/trim_candidates()
	. = ..()
	for(var/mob/P in candidates)
		if(P.mob_weight > MOB_WEIGHT_HEAVY) // никаких сверхтяжёлых кровососов
			candidates -= P
		else if(HAS_TRAIT(P, TRAIT_ROBOTIC_ORGANISM)) // никаких роботов-вампиров из далекого космоса
			candidates -= P

//BLUEMOON ADD END
