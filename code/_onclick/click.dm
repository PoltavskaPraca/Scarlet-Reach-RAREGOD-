/*
	Click code cleanup
	~Sayu
*/

// 1 decisecond click delay (above and beyond mob/next_move)
//This is mainly modified by click code, to modify click delays elsewhere, use next_move and changeNext_move()
/mob/var/next_click	= 0

// THESE DO NOT EFFECT THE BASE 1 DECISECOND DELAY OF NEXT_CLICK
/mob/var/next_move_adjust = 0 //Amount to adjust action/click delays by, + or -
/mob/var/next_move_modifier = 1 //Value to multiply action/click delays by


//Delays the mob's next click/action by num deciseconds
// eg: 10-3 = 7 deciseconds of delay
// eg: 10*0.5 = 5 deciseconds of delay
// DOES NOT EFFECT THE BASE 1 DECISECOND DELAY OF NEXT_CLICK

/mob/proc/changeNext_move(num, hand, override = FALSE)
	next_move = world.time + ((num+next_move_adjust)*next_move_modifier)

/mob/living/changeNext_move(num, hand, override = FALSE)
	var/mod = next_move_modifier
	var/adj = next_move_adjust
	for(var/i in status_effects)
		var/datum/status_effect/S = i
		mod *= S.nextmove_modifier()
		adj += S.nextmove_adjust()
	if(!hand)
		var/check_move = world.time + ((num + adj)*mod)
		if((check_move >= next_move) || override)
			next_move = check_move
		hud_used?.cdmid?.mark_dirty()
		return
	if(hand == 1)
		var/check_move = world.time + ((num + adj)*mod)
		if((check_move >= next_lmove) || override)
			next_lmove = check_move
		next_lmove = world.time + ((num + adj)*mod)
		hud_used?.cdleft?.mark_dirty()
	else
		var/check_move = world.time + ((num + adj)*mod)
		if((check_move >= next_rmove) || override)
			next_rmove = check_move
		next_rmove = world.time + ((num + adj)*mod)
		hud_used?.cdright?.mark_dirty()

/*
	Before anything else, defer these calls to a per-mobtype handler.  This allows us to
	remove istype() spaghetti code, but requires the addition of other handler procs to simplify it.

	Alternately, you could hardcode every mob's variation in a flat ClickOn() proc; however,
	that's a lot of code duplication and is hard to maintain.

	Note that this proc can be overridden, and is in the case of screen objects.
*/
/atom/Click(location,control,params)
	if(flags_1 & INITIALIZED_1)
		SEND_SIGNAL(src, COMSIG_CLICK, location, control, params, usr)
		usr.ClickOn(src, params)
	return

/atom/DblClick(location,control,params)
	if(flags_1 & INITIALIZED_1)
		usr.DblClickOn(src,params)

/atom/MouseWheel(delta_x,delta_y,location,control,params)
	if(flags_1 & INITIALIZED_1)
		usr.MouseWheelOn(src, delta_x, delta_y, params)

/*
	Standard mob ClickOn()
	Handles exceptions: Buildmode, middle click, modified clicks, mech actions

	After that, mostly just check your state, check whether you're holding an item,
	check whether you're adjacent to the target, then pass off the click to whoever
	is receiving it.
	The most common are:
	* mob/UnarmedAttack(atom,adjacent) - used here only when adjacent, with no item in hand; in the case of humans, checks gloves
	* atom/attackby(item,user) - used only when adjacent
	* item/afterattack(atom,user,adjacent,params) - used both ranged and adjacent
	* mob/RangedAttack(atom,params) - used only ranged, only used for tk and laser eyes but could be changed
*/
/mob/proc/ClickOn( atom/A, params )
	var/list/modifiers = params2list(params)

	if(curplaying)
		curplaying.on_mouse_up()

	if(world.time <= next_click)
		return
	next_click = world.time + 1

	if(check_click_intercept(params,A))
		return

	if(notransform)
		return

	if(SEND_SIGNAL(src, COMSIG_MOB_CLICKON, A, params) & COMSIG_MOB_CANCEL_CLICKON)
		return

	if(next_move > world.time)
		return

	if(modifiers["middle"] && atkswinging == "middle")
		if(mmb_intent)
			if(mmb_intent.get_chargetime())
				if(mmb_intent.no_early_release && client?.chargedprog < 100)
					changeNext_move(mmb_intent.clickcd)
					return
	if(modifiers["left"] && atkswinging == "left")
		if(active_hand_index == 1)
			used_hand = 1
			if(next_lmove > world.time)
				return
		else
			used_hand = 2
			if(next_rmove > world.time)
				return
		if(used_intent.get_chargetime())
			if(used_intent.no_early_release && client?.chargedprog < 100)
				var/adf = used_intent.clickcd
				if(istype(rmb_intent, /datum/rmb_intent/aimed))
					adf = round(adf * CLICK_CD_MOD_AIMED)
				if(istype(rmb_intent, /datum/rmb_intent/swift))
					adf = max(round(adf * CLICK_CD_MOD_SWIFT), CLICK_CD_INTENTCAP)
				changeNext_move(adf,used_hand)
				return
	if(modifiers["right"] && oactive && atkswinging == "right")
		if(active_hand_index == 1)
			used_hand = 2
			if(next_rmove > world.time)
				return
		else
			used_hand = 1
			if(next_lmove > world.time)
				return
		if(used_intent.get_chargetime())
			if(used_intent.no_early_release && client?.chargedprog < 100)
				changeNext_move(used_intent.clickcd,used_hand)
				return


//	if(modifiers["shift"] && modifiers["middle"])
//		changeNext_move(CLICK_CD_MELEE)
//		ShiftMiddleClickOn(A)
//		return
//	if(modifiers["shift"] && modifiers["ctrl"])
//		CtrlShiftClickOn(A)
//		return
	if(modifiers["shift"] && modifiers["right"])
		ShiftRightClickOn(A, params)
		return
	if(modifiers["ctrl"] && modifiers["right"])
//		face_atom(A)
		CtrlRightClickOn(A, params)
		return
	if(modifiers["alt"] && modifiers["right"])
		face_atom(A)
		AltRightClickOn(A, params)
		return
//	if(modifiers["shift"] && modifiers["middle"])
//		ShiftMiddleClickOn(A)
//		return
	if(modifiers["middle"])
		MiddleClickOn(A, params)
		return
	if(modifiers["shift"])
		ShiftClickOn(A)
		return
//	if(modifiers["alt"]) // alt and alt-gr (rightalt)
//		AltClickOn(A)
//		return
//	if(modifiers["ctrl"])
//		CtrlClickOn(A)
//		return
	if(modifiers["right"])
		testing("right")
		if(!oactive)
			RightClickOn(A, params)
			return

	if(incapacitated(ignore_restraints = 1))
		return

	if(!atkswinging)
		face_atom(A)

	if(!modifiers["catcher"] && A.IsObscured())
		return

	if(dir == get_dir(A,src)) //they are behind us and we are not facing them
		return

	if(restrained())
		changeNext_move(CLICK_CD_HANDCUFFED)   //Doing shit in cuffs shall be vey slow
		RestrainedClickOn(A)
		return

	if(in_throw_mode)
		if(modifiers["right"])
			if(oactive)
				throw_item(A, TRUE)
				return
		throw_item(A)
		return

	var/obj/item/W = get_active_held_item()
	if(modifiers["right"])
		if(oactive)
			W = get_inactive_held_item()

	if(W == A)
		W.attack_self(src)
		update_inv_hands()
		return

	// operate three levels deep here (item in backpack in src; item in box in backpack in src, not any deeper)
	if(!isturf(A) && A == loc || (A in contents) || (A.loc in contents) || (A.loc && (A.loc.loc in contents)))
		// the above ensures adjacency
		resolveAdjacentClick(A,W,params)
		return

	if (A.loc && ismob(A.loc.loc))
		// we're inside a container inside a mob, so we're almost certainly a saddle, a box, or someone's organs. check if we're adjacent
		if (src.Adjacent(A.loc.loc))
			resolveAdjacentClick(A,W,params)
			return

	if(W)
		if(ismob(A))
			if(CanReach(A,W))
				if(get_dist(get_turf(src), get_turf(A)) <= used_intent.reach)
					if(!used_intent.noaa)
						do_attack_animation(get_turf(A), used_intent.animname, W, used_intent = src.used_intent)
				resolveAdjacentClick(A,W,params)
				return

	if(!loc.AllowClick()) // This is going to stop you from telekinesing from inside a closet, but I don't shed many tears for that
		return
/*
	//This block handles attempting to attack a mob in the direction you clicked
	//without ACTUALLY clicking the mob
	//(Only handles mobs because it's too complicated to determine which atom to attack)
	if((!A.Adjacent(src)) || (!ismob(A) && !istype(A, /obj/item)))
		if(a_intent?.noaa && !A.Adjacent(src))
			resolveRangedClick(A,W,params,used_hand)
			atkswinging = null
			update_warning()
			return
		var/turf/T = get_turf(A)
		if(!A.Adjacent(src))
			var/ddir = get_dir(src,A)
			T = get_step(src,ddir)
		if(T)
			var/list/mobs_here = list()
			for(var/mob/M in T)
				if(M.invisibility || M == src)
					continue
				mobs_here += M
			if(mobs_here.len)
				var/mob/target = pick(mobs_here)
				if(target)
					if(target.Adjacent(src))
						resolveAdjacentClick(target,W,params,used_hand)
						atkswinging = null
						update_warning()
						return
					else //don't ask me how a mob in an adjacent turf can't be adjacent
						resolveRangedClick(target,W,params,used_hand)
						atkswinging = null
						update_warning()
						return
*/

	// Allows you to click on a box's contents, if that box is on the ground, but no deeper than that
	if(isturf(A) || isturf(A.loc) || (A.loc && isturf(A.loc.loc)))
		if(CanReach(A) || CanReach(A, W))
			if(isopenturf(A))
				var/turf/T = A
				if(used_intent.noaa)
					resolveAdjacentClick(A,W,params,used_hand)
					return
				if(T)
					testing("beginautoaim")
					var/list/mobs_here = list()
					for(var/mob/M in T)
						if(M.invisibility || M == src)
							continue
						mobs_here += M
					if(mobs_here.len)
						var/mob/target = pick(mobs_here)
						if(target)
							if(target.Adjacent(src))
								do_attack_animation(T, used_intent.animname, used_intent.masteritem, used_intent = src.used_intent)
								resolveAdjacentClick(target,W,params,used_hand)
								atkswinging = null
								//update_warning()
								return
					if(cmode)
						resolveAdjacentClick(T,W,params,used_hand) //hit the turf
					if(!used_intent.noaa)
						changeNext_move(CLICK_CD_RAPID)
						if(get_dist(get_turf(src), T) <= used_intent.reach)
							do_attack_animation(T, used_intent.animname, used_intent.masteritem, used_intent = src.used_intent)
						if(W)
							playsound(get_turf(src), pick(W.swingsound), 100, FALSE)
							var/adf = used_intent.clickcd
							if(istype(rmb_intent, /datum/rmb_intent/aimed))
								adf = round(adf * CLICK_CD_MOD_AIMED)
							if(istype(rmb_intent, /datum/rmb_intent/swift))
								adf = max(round(adf * CLICK_CD_MOD_SWIFT), CLICK_CD_INTENTCAP)
							changeNext_move(adf)
						else
							playsound(get_turf(src), used_intent.miss_sound, 100, FALSE)
							if(used_intent.miss_text)
								visible_message(span_warning("[src] [used_intent.miss_text]!"), \
												span_warning("I [used_intent.miss_text]!"))
					aftermiss()
					atkswinging = null
					//update_warning()
					return
			else
				resolveAdjacentClick(A,W,params,used_hand)
				atkswinging = null
				//update_warning()
				return
		else // non-adjacent click
			resolveRangedClick(A,W,params,used_hand)
			atkswinging = null
			//update_warning()
			return

	atkswinging = null
	//update_warning()

//Branching path for Adjacent clicks with or without items
//DOES NOT ACTUALLY KNOW IF YOU'RE ADJACENT, DO NOT CALL ON IT'S OWN
/mob/proc/resolveAdjacentClick(atom/A,obj/item/W,params,used_hand)
	if(!A)
		return
	if(W)
		W.melee_attack_chain(src, A, params)
	else
		if(ismob(A))
			var/adf = used_intent.clickcd
			if(istype(rmb_intent, /datum/rmb_intent/aimed))
				adf = round(adf * CLICK_CD_MOD_AIMED)
			if(istype(rmb_intent, /datum/rmb_intent/swift))
				adf = max(round(adf * CLICK_CD_MOD_SWIFT), CLICK_CD_INTENTCAP)
			changeNext_move(adf)
		UnarmedAttack(A,1,params)
	if(mob_timers[MT_INVISIBILITY] > world.time)			
		mob_timers[MT_INVISIBILITY] = world.time
		update_sneak_invis(reset = TRUE)

//Branching path for Ranged clicks with or without items
//DOES NOT ACTUALLY KNOW IF YOU'RE RANGED, DO NoT CALL ON IT'S OWN
/mob/proc/resolveRangedClick(atom/A,obj/item/W,params,used_hand)
	if(!A)
		return
	if(W)
		W.afterattack(A,src,0,params) // 0: not Adjacent
	else
		RangedAttack(A, params)

/mob/proc/swingbarcut()
	client.images -= swingi

/mob/proc/swingiupdate()
	if(swingi && swingtarget)
		swingi.loc = swingtarget.loc

/mob/proc/aftermiss()
	if(ishuman(src))
		var/mob/living/carbon/human/H = src
		H.stamina_add(used_intent.misscost)

//Is the atom obscured by a PREVENT_CLICK_UNDER_1 object above it
/atom/proc/IsObscured()
	if(!isturf(loc)) //This only makes sense for things directly on turfs for now
		return FALSE
	var/turf/T = get_turf_pixel(src)
	if(!T)
		return FALSE
	for(var/atom/movable/AM in T)
		if(AM.flags_1 & PREVENT_CLICK_UNDER_1 && AM.density && AM.layer > layer)
			return TRUE
	return FALSE

/turf/IsObscured()
	for(var/item in src)
		var/atom/movable/AM = item
		if(AM.flags_1 & PREVENT_CLICK_UNDER_1)
			return TRUE
	return FALSE

/atom/movable/proc/CanReach(atom/ultimate_target, obj/item/tool, view_only = FALSE)
	// A backwards depth-limited breadth-first-search to see if the target is
	// logically "in" anything adjacent to us.
	var/list/direct_access = DirectAccess()
	var/depth = 1 + (view_only ? STORAGE_VIEW_DEPTH : INVENTORY_DEPTH)

	var/list/closed = list()
	var/list/checking = list(ultimate_target)
	while (checking.len && depth > 0)
		var/list/next = list()
		--depth

		for(var/atom/target in checking)  // will filter out nulls
			if(closed[target] || isarea(target))  // avoid infinity situations
				continue
			closed[target] = TRUE
			var/usedreach = 1
			if(tool)
				usedreach = tool.reach
			if(ismob(src))
				var/mob/user = src
				if(user.used_intent)
					usedreach = user.used_intent.reach
			if(isturf(target) || isturf(target.loc) || (target in direct_access)) //Directly accessible atoms
				if(Adjacent(target) || ( (tool || (!iscarbon(src) && usedreach >= 2)) && CheckToolReach(src, target, usedreach))) //Adjacent or reaching attacks
					return TRUE

			if (!target.loc)
				continue

			if(!(SEND_SIGNAL(target.loc, COMSIG_ATOM_CANREACH, next) & COMPONENT_BLOCK_REACH))
				next += target.loc

		checking = next
	return FALSE

/atom/movable/proc/DirectAccess()
	return list(src, loc)

/mob/DirectAccess(atom/target)
	return ..() + contents

/mob/living/DirectAccess(atom/target)
	return ..() + GetAllContents()

/atom/proc/AllowClick()
	return FALSE

/turf/AllowClick()
	return TRUE

/proc/CheckToolReach(atom/movable/here, atom/movable/there, reach)
	if(!here || !there)
		return
	switch(reach)
		if(0)
			return FALSE
		if(1)
			return FALSE //here.Adjacent(there)
		if(2 to INFINITY)
			var/obj/dummy = new(get_turf(here))
			dummy.pass_flags |= PASSTABLE
			dummy.invisibility = INVISIBILITY_ABSTRACT
			for(var/i in 1 to reach) //Limit it to that many tries
				var/turf/T = get_step(dummy, get_dir(dummy, there))
				if(dummy.CanReach(there))
					qdel(dummy)
					return TRUE
				if(!dummy.Move(T)) //we're blocked!
					qdel(dummy)
					return
			qdel(dummy)

// Default behavior: ignore double clicks (the second click that makes the doubleclick call already calls for a normal click)
/mob/proc/DblClickOn(atom/A, params)
	return


/*
	Translates into attack_hand, etc.

	Note: proximity_flag here is used to distinguish between normal usage (flag=1),
	and usage when clicking on things telekinetically (flag=0).  This proc will
	not be called at ranged except with telekinesis.

	proximity_flag is not currently passed to attack_hand, and is instead used
	in human click code to allow glove touches only at melee range.
*/
/mob/proc/UnarmedAttack(atom/A, proximity_flag, params)
	return

/*
	Ranged unarmed attack:

	This currently is just a default for all mobs, involving
	laser eyes and telekinesis.  You could easily add exceptions
	for things like ranged glove touches, spitting alien acid/neurotoxin,
	animals lunging, etc.
*/
/mob/proc/RangedAttack(atom/A, params)
	SEND_SIGNAL(src, COMSIG_MOB_ATTACK_RANGED, A, params)
/*
	Restrained ClickOn

	Used when you are handcuffed and click things.
	Not currently used by anything but could easily be.
*/
/mob/proc/RestrainedClickOn(atom/A)
	return

/**
  *Middle click
  *Mainly used for swapping hands
  */
/mob/proc/MiddleClickOn(atom/A, params)
	. = SEND_SIGNAL(src, COMSIG_MOB_MIDDLECLICKON, A)
	if(. & COMSIG_MOB_CANCEL_CLICKON)
		return
//	swap_hand()

/atom/proc/MiddleClick(mob/user, params)
	return

/turf/open/MiddleClick(mob/user, params)
	if(!user.TurfAdjacent(src))
		return
	if(user.get_active_held_item())
		return
	var/list/atom/atomy = list()
	var/list/atomcounts = list()
	var/list/atomrefs = list()
	var/list/overrides = list()
	for(var/image/I in user.client.images)
		if(I.loc && I.loc.loc == src && I.override)
			overrides += I.loc
	for(var/obj/item/A in src)
		if(!A.mouse_opacity)
			continue
		if(A.invisibility > user.see_invisible)
			continue
		if(overrides.len && (A in overrides))
			continue
		if(A.IsObscured())
			continue
		if(!A.name)
			continue
		var/AN = A.name
		atomcounts[AN] += 1
		if(!atomrefs[AN]) // Only the FIRST item that matches the same name
			atomrefs[AN] = A // If this one item can't get picked up, sucks to be you
	if(length(atomrefs))
		for(var/AC in atomrefs)
			var/AD = "[AC] ([atomcounts[AC]])"
			atomy[AD] = atomrefs[AC]
	var/atom/AB = input(user, "What will I take?","Items on [src.name ? "\the [src.name]:" : "the floor:"]",null) as null|anything in atomy
	if(!AB)
		return
	if(QDELETED(atomy[AB]))
		return
	if(atomy[AB].loc != src)
		return
	var/AE = atomy[AB]
	user.used_intent = user.a_intent
	user.UnarmedAttack(AE,1,params)

/mob/proc/ShiftMiddleClickOn(atom/A, params)
	. = SEND_SIGNAL(src, COMSIG_MOB_MIDDLECLICKON, A)
	if(. & COMSIG_MOB_CANCEL_CLICKON)
		return
//	A.AltClick(src)
//	else
//		to_chat(src, span_warning("I need an empty hand to sort through the items here."))


/*
	Shift click
	For most mobs, examine.
	This is overridden in ai.dm
*/
/mob/proc/ShiftClickOn(atom/A)
	A.ShiftClick(src)
	return
/atom/proc/ShiftClick(mob/user)
	SEND_SIGNAL(src, COMSIG_CLICK_SHIFT, user)
	if(user.client && user.client.eye == user || user.client.eye == user.loc)
		user.examinate(src)
	return

/*
	Ctrl click
	For most objects, pull
*/

/mob/proc/CtrlClickOn(atom/A)
	if(. & COMSIG_MOB_CANCEL_CLICKON)
		return
	A.CtrlClick(src)

/atom/proc/CtrlClick(mob/user)
	SEND_SIGNAL(src, COMSIG_CLICK_CTRL, user)
	return


/*
	Alt click
	Unused except for AI
*/
/mob/proc/AltClickOn(atom/A, params)
	. = SEND_SIGNAL(src, COMSIG_MOB_ALTCLICKON, A)
	if(. & COMSIG_MOB_CANCEL_CLICKON)
		return

/atom/proc/AltClick(mob/user)
	SEND_SIGNAL(src, COMSIG_CLICK_ALT, user)
	return


// Use this instead of /mob/proc/AltClickOn(atom/A) where you only want turf content listing without additional atom alt-click interaction
/atom/proc/AltClickNoInteract(mob/user, atom/A)
	var/turf/T = get_turf(A)
	if(T && user.TurfAdjacent(T))
		user.listed_turf = T
		user.client.statpanel = T.name

/mob/proc/TurfAdjacent(turf/T)
	return T.Adjacent(src)

/*
	Control+Shift click
	Unused except for AI
*/
/mob/proc/CtrlShiftClickOn(atom/A)
	A.CtrlShiftClick(src)
	return




/atom/proc/CtrlShiftClick(mob/user)
	SEND_SIGNAL(src, COMSIG_CLICK_CTRL_SHIFT)
	return

/mob/proc/AltRightClickOn(atom/A, params)
	SEND_SIGNAL(src, COMSIG_CLICK_ALT, A)
	A.AltRightClick(src)

/atom/proc/AltRightClick(mob/user)
//	SEND_SIGNAL(src, COMSIG_CLICK_ALT, user)
	var/turf/T = get_turf(src)
	if(T && (isturf(loc) || isturf(src)) && user.TurfAdjacent(T))
		user.listed_turf = T
		user.client.statpanel = T.name

/mob/proc/CtrlRightClickOn(atom/A, params)
	linepoint(A, params)
	return

/*
	Misc helpers
	face_atom: turns the mob towards what you clicked on
*/

/atom/proc/face_me(location, control, params)
	return src

// Simple helper to face another atom, much nicer than byond's dir = get_dir(src,A) which is biased in some ugly ways
/atom/proc/face_atom(atom/A, location, control, params)
	if(!A)
		return
	if(!A.xyoverride)
		if((!A || !x || !y || !A.x || !A.y))
			return
	var/atom/holder = A.face_me(location, control, params)
	if(!holder)
		return
	var/dx = holder.x - x
	var/dy = holder.y - y
	if(!dx && !dy) // Wall items are graphically shifted but on the floor
		if(holder.pixel_y > 16)
			setDir(NORTH)
		else if(holder.pixel_y < -16)
			setDir(SOUTH)
		else if(holder.pixel_x > 16)
			setDir(EAST)
		else if(holder.pixel_x < -16)
			setDir(WEST)
		return

	if(abs(dx) < abs(dy))
		if(dy > 0)
			setDir(NORTH)
		else
			setDir(SOUTH)
	else
		if(dx > 0)
			setDir(EAST)
		else
			setDir(WEST)

/mob/face_atom(atom/A)
	if(!canface())
		return FALSE
	..()

/mob/living/face_atom(atom/A)
	var/olddir = dir
	..()
	if(dir != olddir)
		last_dir_change = world.time
		sprinted_tiles = 0

//debug
/atom/movable/screen/proc/scale_to(x1,y1)
	if(!y1)
		y1 = x1
	var/matrix/M = new
	M.Scale(x1,y1)
	transform = M

/atom
	var/xyoverride = FALSE //so we can 'face' the click catcher even though it doesn't have an x or a y

/atom/movable/screen/click_catcher
	icon = 'icons/mob/screen_gen.dmi'
	icon_state = "catcher"
	plane = CLICKCATCHER_PLANE
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	screen_loc = "CENTER"
	xyoverride = TRUE
	blockscharging = FALSE

#define MAX_SAFE_BYOND_ICON_SCALE_TILES (MAX_SAFE_BYOND_ICON_SCALE_PX / world.icon_size)
#define MAX_SAFE_BYOND_ICON_SCALE_PX (33 * 32)			//Not using world.icon_size on purpose.

/atom/movable/screen/click_catcher/proc/UpdateGreed(view_size_x = 15, view_size_y = 15)
	var/icon/newicon = icon('icons/mob/screen_gen.dmi', "catcher")
	var/ox = min(MAX_SAFE_BYOND_ICON_SCALE_TILES, view_size_x)
	var/oy = min(MAX_SAFE_BYOND_ICON_SCALE_TILES, view_size_y)
	var/px = view_size_x * world.icon_size
	var/py = view_size_y * world.icon_size
	var/sx = min(MAX_SAFE_BYOND_ICON_SCALE_PX, px)
	var/sy = min(MAX_SAFE_BYOND_ICON_SCALE_PX, py)
	newicon.Scale(sx, sy)
	icon = newicon
	screen_loc = "CENTER-[(ox-1)*0.5],CENTER-[(oy-1)*0.5]"
	var/matrix/M = new
	M.Scale(px/sx, py/sy)
	transform = M

/atom/movable/screen/click_catcher/Click(location, control, params)
	var/list/modifiers = params2list(params)
	var/turf/T = params2turf(modifiers["screen-loc"], get_turf(usr.client ? usr.client.eye : usr), usr.client)
	params += "&catcher=1"
	if(T)
		T.Click(location, control, params)
	. = 1

/atom/movable/screen/click_catcher/face_me(location, control, params)
	var/list/modifiers = params2list(params)
	var/turf/T = params2turf(modifiers["screen-loc"], get_turf(usr.client ? usr.client.eye : usr), usr.client)
	if(T)
		return T


/* MouseWheelOn */

/mob/proc/MouseWheelOn(atom/A, delta_x, delta_y, params)
	return

/mob/living/MouseWheelOn(atom/A, delta_x, delta_y, params)
	var/list/modifiers = params2list(params)
	if(modifiers["shift"])
		if(delta_y > 0)
			aimheight_change("up")
		else
			aimheight_change("down")

/mob/dead/observer/MouseWheelOn(atom/A, delta_x, delta_y, params)
	return
/*	var/list/modifier = params2list(params)
	if(modifier["shift"])
		var/view = 0
		if(delta_y > 0)
			view = -1
		else
			view = 1
		add_view_range(view)*/

/mob/proc/check_click_intercept(params,A)
	//Client level intercept
	if(client && client.click_intercept)
		if(call(client.click_intercept, "InterceptClickOn")(src, params, A))
			return TRUE

	//Mob level intercept
	if(click_intercept)
		if(call(click_intercept, "InterceptClickOn")(src, params, A))
			return TRUE

	return FALSE

/* RightClickOn */

/atom/proc/rmb_self(mob/user)
	return

/mob/proc/rmb_on(atom/A, params)
	return

/mob/proc/RightClickOn(atom/A, params)
	if(A.Adjacent(src))
		if(A.loc == src && (A == get_active_held_item()) )
			A.rmb_self(src)
		else
			rmb_on(A, params)
	else if(used_intent.rmb_ranged)
		used_intent.rmb_ranged(A, src) //get the message from the intent
	changeNext_move(CLICK_CD_RAPID)
	if(isturf(A.loc))
		face_atom(A)

/mob/proc/TargetMob(mob/target)
	if(ismob(target))
		if(targetting) //untarget old target
			UntargetMob()
		targetting = target
		if(!fixedeye) //If fixedeye isn't already enabled, we need to set this var
			nodirchange = TRUE
		tempfixeye = TRUE //Change icon to 'target' red eye
		targeti = image('icons/mouseover.dmi', targetting.loc, "target", ABOVE_HUD_LAYER+0.1)
		var/icon/I = icon(icon, icon_state, dir)
		targeti.pixel_y = I.Height() - world.icon_size - 4
		targeti.pixel_x = -1
		src.client.images |= targeti
		for(var/atom/movable/screen/eye_intent/eyet in hud_used.static_inventory)
			eyet.update_icon(src) //Update eye icon
	else
		UntargetMob()

/mob/proc/UpdateTargetImage()
	if(targeti)
		targeti.loc = targetting.loc

/mob/proc/FaceTarget()
	return

/mob/proc/UntargetMob()
	targetting = null
	tempfixeye = FALSE
	if(!fixedeye)
		nodirchange = FALSE
	src.client.images -= targeti
	//clear hud icon
	for(var/atom/movable/screen/eye_intent/eyet in hud_used.static_inventory)
		eyet.update_icon(src)

/mob/proc/ShiftRightClickOn(atom/A, params)
//	linepoint(A, params)
//	A.ShiftRightClick(src)
	return

/mob/living/ShiftRightClickOn(atom/A, params)
	var/turf/T = get_turf(A)
//	var/turf/MT = get_turf(src)
	if(stat)
		return
	if(get_dist(src, A) <= 2)
		if(T == loc)
			look_up()
		else
			if(istransparentturf(T))
				look_down(T)
			else
				look_further(T)
	else
		look_further(T)

/atom/proc/ShiftRightClick(mob/user)
	SEND_SIGNAL(src, COMSIG_CLICK_RIGHT_SHIFT, user)
	if(user.client && user.client.eye == user || user.client.eye == user.loc)
		user.examinate(src)

/mob/proc/addtemptarget()
	if(targetting)
		if(targetting == swingtarget)
			return
		UntargetMob()
	temptarget = TRUE
	targetting = swingtarget
	if(!fixedeye)
		nodirchange = TRUE
	tempfixeye = TRUE
	for(var/atom/movable/screen/eye_intent/eyet in hud_used.static_inventory)
		eyet.update_icon(src) //Update eye icon
