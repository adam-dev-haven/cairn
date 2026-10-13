# One guide per calisthenics skill step, same treatment as the band exercises:
# what you need, how to set up, how to do it, what goes wrong, and a photo where the free
# exercise database has one. Every step is doable at home: floor, wall, a chair or sofa, a
# heavy table, a towel, the five bands, the handles and the door anchor. Nothing needs a bar.
#
# Key: (skill id, step name). gen_swift.py writes them to Sources/Cairn/Model/LibraryGuides.swift.
# Photos: ids of Training/img/<id>/ (two frames each) or "extra-<name>". note = what the photo shows.

G = {}

def g(skill, step, kit, setup, how, mistakes, img=(), note=""):
    G[(skill, step)] = dict(kit=kit, setup=setup, how=list(how), mistakes=list(mistakes), img=list(img), note=note)

DB = "Photo shows the dumbbell version. Same body position; the band replaces the weight."
CABLE = "Photo shows the cable version. Same body position; your band on the door anchor replaces the cable."
BAR = "Photo shows a bar or bench. At home you use the table or chair named in the set-up; the body position is the same."

# ---------------------------------------------------------------------------------- Push-up
g("pushup", "Incline push-up", "A heavy table edge or the kitchen counter",
  "Hands on the edge of a table or counter that can't slide, a little wider than the shoulders. Walk the feet back until the body is one straight line.",
  ["Squeeze glutes and abs so the hips don't sag.", "Lower the chest to the edge, elbows about 45° from the ribs.",
   "Push the surface away until the shoulder blades wrap round the ribs.",
   "When 3 × 10 is clean, use a lower surface: a chair seat, then the floor."],
  ["Hips sagging", "Elbows flared out", "A surface that moves"], ["Incline_Push-Up"], BAR)
g("pushup", "Push-up", "Floor, or the handles",
  "Hands on the floor or on the handles (easier on the wrists), slightly wider than the shoulders. Fingers spread, grip the floor.",
  ["One straight line from heels to head. Glutes and abs tight.", "Elbows about 45° from the ribs. Chest to the floor.",
   "At the top push the floor away until the shoulder blades wrap round the ribs.", "Two seconds down, one up."],
  ["Hips sagging", "Head poking forward", "Half reps"], ["Pushups"])
g("pushup", "Feet-elevated push-up", "A chair or the sofa seat",
  "Feet on a chair seat or the sofa, hands on the floor under the shoulders. Body in a line, slightly tilted downhill.",
  ["Same push-up, more of your weight on the shoulders.", "Keep the ribs down so the lower back doesn't arch.",
   "Chest to the floor, elbows about 45°.", "Higher feet make it harder: seat, then sofa back, once 3 × 10 is clean."],
  ["Hips piking up", "Lower back arching", "Chair that slides on the floor"], ["Push-Ups_With_Feet_Elevated"])
g("pushup", "Band-resisted push-up", "One band, two handles",
  "Put a band across your upper back, below the neck. Clip the two hooks to the handles. Hold the handles on the floor as your hands and take the push-up position. Start with the 4.5 or 9 kg band.",
  ["Same push-up. The band gets heavier near the top, so finish every rep.", "Keep the band flat across the shoulder blades, not riding up the neck.",
   "Stop 1–2 reps short of failure.", "Move up a band when 3 × 10 lands twice."],
  ["Letting the band pull the shoulders forward", "Short reps at the top"], ["Pushups"],
  "Photo shows the plain push-up. The band across the back makes the top harder.")
g("pushup", "Archer push-up", "Floor",
  "Hands about twice shoulder-width, fingers turned slightly out. Body in one line.",
  ["Lower the chest toward one hand while the other arm stays straight, palm flat.", "The bent arm does nearly all the work.",
   "Push back up and go to the other side. Count each side as one rep.", "Slide the straight hand further out to make it harder."],
  ["Both arms bending", "Hips twisting to one side", "Wrists collapsing"], [])

# ---------------------------------------------------------------------------------- Vertical pull
g("pullup", "Band pulldown", "Bands, handles, door anchor",
  "Anchor the band at the top of the door. Kneel facing the door, far enough back for tension. Hold a handle in each hand, arms long above you.",
  ["Pull the elbows down and back to the ribs. The hands finish by the chest.", "Squeeze the shoulder blades down and together at the bottom.",
   "Let the arms go back up slowly. Lean back only a little.", "Start around 31.5 kg (18 + 13.5). Stop with two reps in the tank."],
  ["Shrugging the shoulders up", "Leaning back to heave", "Letting the band yank the arms up"], ["Wide-Grip_Lat_Pulldown"], CABLE)
g("pullup", "Heavy pulldown", "Three bands stacked",
  "Same set-up, with three bands stacked on the anchor: around 45 kg (for example 22.5 + 13.5 + 9). Check the door is closed and the anchor sits on the hinge side.",
  ["Same pull, slower: two seconds down, one second hold, two up.", "If the shoulders creep up, drop one band.",
   "Stay upright, ribs down.", "Move on when 3 × 10 lands twice."],
  ["Hips rocking back and forth", "Elbows flaring out"], ["Wide-Grip_Lat_Pulldown"], CABLE)
g("pullup", "Slow pulldown", "Three bands stacked",
  "Same as the heavy pulldown. The work is in the way back up.",
  ["Pull to the chest in one second.", "Let the band raise the arms over five seconds. Don't let go.",
   "This is the same fight as the lowering part of a pull-up.", "Count the five seconds out loud."],
  ["Dropping the arms up in one go", "Losing the shoulder blades on the way up"], ["Wide-Grip_Lat_Pulldown"], CABLE)
g("pullup", "Straight-arm pulldown", "Bands, handles, door anchor (high)",
  "Anchor the band at the top of the door. Stand facing it, step back until tight. Hands on the handles at about forehead height, arms nearly straight, a small bend in the elbows.",
  ["Sweep both straight arms down to the thighs.", "Hinge a little at the hips and keep the ribs still.",
   "Feel the sides of the back under the armpits working.", "Slowly return to the start. The elbows stay locked in that small bend."],
  ["Bending the elbows into a pushdown", "Rocking the torso", "Shrugging"], ["Straight-Arm_Pulldown"], CABLE)
g("pullup", "One-arm pulldown", "One handle, bands, door anchor",
  "Kneel side-on to the anchor, or face it, with one handle in one hand. The free hand rests on the thigh.",
  ["Pull the elbow down and into the ribs.", "The ribs don't twist. If the torso turns, drop a band.",
   "Slow return, shoulder blade follows the arm up.", "Do all reps on one side, then the other."],
  ["Twisting the torso", "Pulling with the hand, not the elbow"], ["Wide-Grip_Lat_Pulldown"], CABLE)
g("pullup", "Heavy one-arm pulldown", "Three bands, one handle",
  "Same as the one-arm pulldown, with around 45 kg on the anchor.",
  ["Lock the ribs and the glutes.", "Elbow to the ribs in one second, back up in three.",
   "A short pause at the bottom, shoulder blade down.", "This is the nearest the bands get to a pull-up. If the elbows ache, go back a step."],
  ["Leaning away from the band", "Grip giving out first: use a strap or a towel loop"], ["Wide-Grip_Lat_Pulldown"], CABLE)

# ---------------------------------------------------------------------------------- Row
g("row", "Band row", "Band, handles",
  "Sit on the floor, legs long. Loop the band round both feet, a handle in each hand. Sit tall with a slight lean forward.",
  ["Pull the handles to the lower ribs, elbows brushing past the body.", "Squeeze the shoulder blades together for a second.",
   "Slow return, arms long, a small stretch across the back.", "Start around 36 kg. Two bands at least; one is too light."],
  ["Rocking the torso", "Shrugging", "Letting the shoulders round forward at the end"], ["Seated_Cable_Rows"], CABLE)
g("row", "Table row, knees bent", "A heavy, solid table",
  "Lie on the floor under the edge of a heavy dining table. Push the table hard sideways first: if it moves, don't. Grip the edge with both hands, a little wider than the shoulders, knees bent, feet flat.",
  ["Pull the chest up to the table edge, shoulder blades back and down.", "Hips stay up in line with the shoulders and knees.",
   "Lower until the arms are straight.", "Overhand grip, thumbs round the edge."],
  ["Hips sagging", "Chin poking forward", "A table that shifts"], ["Inverted_Row"], BAR)
g("row", "Table row, straight body", "A heavy, solid table",
  "Same position, legs straight, heels on the floor.",
  ["Body is one plank line from heels to head.", "Pull the chest to the edge, elbows about 45° from the ribs.",
   "Two seconds down.", "If the hips sag, bend the knees again."],
  ["Hips sagging", "Half reps"], ["Inverted_Row"], BAR)
g("row", "Table row, feet on a chair", "A heavy table, a chair",
  "Same, with the heels on a chair seat so the body slopes slightly upward.",
  ["Pulling from higher up loads the lats more.", "Hips and ribs stay still.",
   "Chest to the edge, shoulder blades together.", "Make sure the chair can't slide: back against a wall or a heavy object."],
  ["A chair that slides", "Hips dropping"], ["Inverted_Row"], BAR)
g("row", "Table row, 3 s pause", "A heavy table, a chair",
  "Same as the elevated row.",
  ["Pull up in one second.", "Hold the chest at the edge for three seconds, shoulder blades squeezed.",
   "Lower slowly.", "Stop the set when the hold starts to shake apart."],
  ["Cutting the pause short", "Shrugging at the top"], ["Inverted_Row"], BAR)

# ---------------------------------------------------------------------------------- Dip
g("dip", "Close-grip push-up", "Floor",
  "Push-up position, hands under the chest, thumbs and forefingers nearly touching.",
  ["Elbows brush the ribs on the way down.", "Chest to the hands, then push the floor away.",
   "The triceps do more work here than in a normal push-up.", "Wrists hurt: turn the fingers out a little or use the handles."],
  ["Elbows flaring", "Hips sagging", "Head poking forward"], ["Push-Ups_-_Close_Triceps_Position"])
g("dip", "Chair dip, knees bent", "A sturdy chair against a wall",
  "Put the chair against a wall, or on a rug so it can't slide, and never one with wheels. Sit on the edge, hands on the seat beside the hips, fingers forward. Walk the feet out and slide the bum off the seat, knees bent.",
  ["Bend the elbows straight back until the upper arm is about level with the floor.", "Keep the back close to the chair.",
   "Press up until the arms are straight.", "Stop higher if the front of the shoulder pinches."],
  ["Elbows flared out", "Shoulders rolling forward at the bottom", "Going lower than a 90° elbow"], ["Bench_Dips"], BAR)
g("dip", "Chair dip, legs straight", "A sturdy chair against a wall",
  "Same, with the legs straight and the heels on the floor.",
  ["More of your weight is on the arms now.", "Keep the shoulders pushed down away from the ears.",
   "Elbows point straight back.", "Slow and controlled; no bouncing at the bottom."],
  ["Hips drifting away from the chair", "Shrugging"], ["Bench_Dips"], BAR)
g("dip", "Chair dip, feet on a chair", "Two sturdy chairs",
  "Hands on one chair, heels on a second chair opposite. Both against a wall or a heavy object.",
  ["Lower until the elbows reach about 90°.", "Press up to a locked-out top.",
   "Keep the chest open, shoulders back.", "Hardest of the chair versions: only when the straight-leg one feels easy."],
  ["Chairs sliding", "Going lower than a 90° elbow"], ["Bench_Dips"], BAR)
g("dip", "Slow chair dip", "Two sturdy chairs",
  "Same position.",
  ["Four seconds down, no pause at the bottom, one second up.", "Stop at a 90° elbow.",
   "The slow lowering builds the strength for deeper dips later.", "Shoulder pinch or ache: back to straight legs."],
  ["Dropping the last part", "Shoulders rolling forward"], ["Bench_Dips"], BAR)

# ---------------------------------------------------------------------------------- Hollow hold
g("hollow", "Dead bug", "Floor",
  "On your back, arms straight up toward the ceiling, knees bent at 90° over the hips.",
  ["Press the lower back flat into the floor and keep it there.", "Lower the opposite arm and leg slowly toward the floor.",
   "Come back and switch sides.", "If the back arches off, shorten the reach."],
  ["Lower back lifting off", "Rushing the reps", "Holding the breath"], ["Dead_Bug"])
g("hollow", "Tuck hollow hold", "Floor",
  "On your back. Knees to the chest, arms by the sides or crossed on the chest.",
  ["Press the lower back flat. Pull the ribs down toward the hips.", "Lift the shoulders and the feet a few centimetres off the floor.",
   "Chin slightly tucked. Breathe in small breaths.", "Hold. Stop the set when the low back lifts."],
  ["Lower back arching", "Neck straining forward"], [])
g("hollow", "Hollow hold", "Floor",
  "On your back. Arms by the ears, legs straight.",
  ["Lower back glued to the floor, ribs pulled down.", "Lift the shoulders and heels a hand's height off the floor.",
   "The lower the legs, the harder it is. Keep them high until the back stays down.", "Squeeze the glutes and the thighs."],
  ["Lower back arching", "Legs too low for your back", "Holding the breath"], [])
g("hollow", "Hollow hold, 60 s", "Floor",
  "Same hold, longer.",
  ["Breathe through the nose in short breaths.", "If it shakes, don't drop: lift the legs a bit and keep the back down.",
   "Hold for one 60 s set, with a clean back all the way.", "Record the time. This is the Hollow Man quest."],
  ["Letting the back arch to survive the last 10 s"], [])

# ---------------------------------------------------------------------------------- L-sit
g("lsit", "Foot-supported L-sit", "Two stacks of books or yoga blocks",
  "Sit between two stacks of books or two blocks, about shoulder-width apart, on a mat. Hands on the stacks, fingers forward. Legs out, heels on the floor.",
  ["Press the hands down and lift the bum off the floor.", "Shoulders down away from the ears, arms locked.",
   "Heels stay on the floor, toes pulled up.", "Hold, then sit down slowly."],
  ["Shrugging up to the ears", "Bent elbows", "Stacks that wobble: use something steady"], ["extra-lsit"],
  "Photo shows the full L-sit on parallettes. At home you do the first rung on blocks, heels down.")
g("lsit", "One-leg L-sit", "Blocks or books",
  "Same set-up, one heel on the floor, the other leg lifted straight.",
  ["Lift one leg straight out in front, toes pointed.", "Hold with the arms locked and the shoulders pressed down.",
   "Switch legs between sets.", "Bum stays high; if it sags, drop back to both feet."],
  ["Bent elbows", "Lifted leg dropping"], ["extra-lsit"], "Photo shows the full L-sit on parallettes. One leg stays down in this step.")
g("lsit", "Tuck L-sit", "Blocks or books",
  "Same set-up. Both feet leave the floor.",
  ["Press up, knees pulled toward the chest.", "Arms locked, shoulders low.", "Hold as long as the arms stay straight.",
   "Lean back slightly if the tuck won't stay up."],
  ["Bent arms", "Shoulders creeping up"], ["extra-lsit"], "Photo shows the full L-sit. In this step the knees stay bent.")
g("lsit", "L-sit", "Blocks or books",
  "Same set-up. Legs straight out in front.",
  ["Squeeze the thighs together and point the toes.", "Press down hard through the hands.",
   "Hips stay above the hands, legs near horizontal.", "Cramping hip flexors are normal early. Shake it out."],
  ["Legs drooping", "Rounding the lower back"], ["extra-lsit"])

# ---------------------------------------------------------------------------------- Wall handstand
g("handstand", "Pike hold", "A chair or the sofa seat",
  "Hands on the floor, feet on a chair seat, hips high over the hands. The body makes an upside-down V.",
  ["Push the floor away so the shoulders open up.", "Head between the arms, looking at your feet or the floor.",
   "Straight arms, ribs in.", "Walk the hands closer to the chair as it gets easier."],
  ["Bent elbows", "Sinking into the shoulders"], [])
g("handstand", "Chest-to-wall hold", "A bare wall and a mat",
  "Start in push-up position with the feet at the wall. Walk the feet up the wall as the hands walk toward it, until the chest faces the wall and the hands are a hand-length away.",
  ["Push tall through the shoulders, ears between the arms.", "Squeeze glutes and belly, body as straight as you can.",
   "Walk down by reversing the walk; never kick out.", "Warm the wrists first."],
  ["Banana back", "Shrugging the shoulders to the ears", "Hands too far from the wall"], ["Handstand_Push-Ups"],
  "Photo shows a handstand push-up. The body line at the top is what you aim for here.")
g("handstand", "Chest-to-wall, 60 s", "A bare wall and a mat",
  "Same position, longer.",
  ["Push the floor away the entire time.", "Breathe slowly.",
   "If the hold falls apart, walk down and rest. Quality only.", "Two sets of 60 s."],
  ["Banana back", "Sagging shoulders"], ["Handstand_Push-Ups"], "Photo shows a handstand push-up. The body line at the top is what you aim for here.")
g("handstand", "Toe pulls off the wall", "A bare wall and a mat",
  "In the chest-to-wall hold, with the toes just touching the wall.",
  ["Lift one toe, then both, off the wall for a second.", "Balance by pressing the fingertips into the floor.",
   "Fall back to the wall if you tip. Don't twist out.", "Five holds of five seconds."],
  ["Bending the arms", "Kicking off the wall"], ["Handstand_Push-Ups"], "Photo shows a handstand push-up. The body line at the top is what you aim for here.")
g("handstand", "Kick-up to freestanding", "A mat and open floor",
  "A clear floor with a mat. Learn the bail-out first: step out of the handstand by turning one hand, like a cartwheel.",
  ["Hands shoulder-width, fingers spread, gaze between the hands.", "Kick up with the stronger leg, the other follows.",
   "Hold, adjust with the fingers, then bail out sideways.", "Practise the bail-out until you can do it without thinking."],
  ["Kicking too hard and going over", "No bail-out plan"], ["Handstand_Push-Ups"], "Photo shows a handstand push-up. The body line at the top is what you aim for here.")

# ---------------------------------------------------------------------------------- Pistol squat
g("pistol", "Split squat", "A chair behind you (optional)",
  "A long step forward, back heel up. Later: the back foot on a chair or the sofa.",
  ["Torso tall, front foot flat.", "Drop the back knee straight down toward the floor.",
   "Drive through the whole front foot.", "Add load by standing on a band with the handles at your shoulders."],
  ["Front knee caving in", "Stance too short, heel lifts"], ["Split_Squat_with_Dumbbells"], DB)
g("pistol", "Chair pistol", "A chair",
  "Stand in front of a chair, one foot lifted. A sturdy chair against a wall, or a firm sofa edge.",
  ["Sit down onto the chair on one leg, the other leg held out in front.", "Stand up on the same leg without pushing off with the hands.",
   "Knee over the middle of the foot.", "Use a lower seat over time: a pile of books on the chair at first, taken away later."],
  ["Knee collapsing in", "Falling back onto the seat", "Heel lifting"], ["Kettlebell_Pistol_Squat"],
  "Photo shows the full pistol with a weight held out in front. At home the chair catches you.")
g("pistol", "Assisted pistol", "A door frame, or a band on the door anchor",
  "Hold the door frame or a post with one hand, or a band looped from the door anchor held in both hands, just enough to help.",
  ["Squat all the way down on one leg, free leg out in front.", "Use the hands to correct your balance, not to pull yourself up.",
   "Heel down, knee tracking over the toes.", "Use the help as little as you can."],
  ["Pulling up on the support", "Heel lifting"], ["Kettlebell_Pistol_Squat"],
  "Photo shows the full pistol with a weight held out in front.")
g("pistol", "Pistol negative", "A mat, a chair behind you as a catch",
  "A chair behind you as a safety catch.",
  ["Lower all the way down on one leg over four seconds.", "Free leg stays out in front.",
   "Sit on the chair or put the other foot down, then stand with two legs.", "Heel stays on the floor all the way."],
  ["Dropping the last part", "Knee caving in"], ["Kettlebell_Pistol_Squat"], "Photo shows the full pistol with a weight held out in front.")
g("pistol", "Pistol squat", "Open floor",
  "Stand on one leg, the other leg held out in front, arms forward.",
  ["Squat down on one leg, heel down.", "Stand up from the bottom on the same leg.",
   "Arms forward for balance, chest tall.", "Knee tracks over the toes the whole way."],
  ["Knee collapsing in", "Heel lifting", "Rounding the lower back at the bottom"], ["Kettlebell_Pistol_Squat"],
  "Photo shows the pistol with a weight held out in front. You do it without the weight.")

# ---------------------------------------------------------------------------------- Frog stand to crow
g("crow", "Wrist warm-up", "A mat or a rug",
  "On all fours, hands under the shoulders.",
  ["Circle the wrists slowly in both directions.", "Rock the body forward and back over the hands, fingers spread.",
   "Turn the hands out to the sides and rock again.", "One minute before every session."],
  ["Going too far into pain", "Skipping it"], [])
g("crow", "Frog stand", "A mat or a rug, and a pillow",
  "Squat with the hands flat on the floor, fingers spread. Put the knees on the backs of the upper arms. A pillow in front of your face.",
  ["Lean forward, shifting the weight onto the hands.", "Lift one foot, then the other, until both float.",
   "Look a metre ahead, not down.", "Hold for ten seconds."],
  ["Looking down at the feet", "Elbows bending fully", "Rushing the lean"], ["extra-crow"],
  "Photo shows a crow pose. In the frog stand the knees rest lower on the arms and are wider.")
g("crow", "Crow", "A mat or a rug, and a pillow",
  "Same, with the knees higher on the upper arms and the arms straighter.",
  ["Round the upper back and press the floor away.", "Pull the heels toward the bum.",
   "Gaze a metre ahead.", "Falling forward: that's why the pillow is there."],
  ["Elbows flaring", "Head dropped"], ["extra-crow"])
g("crow", "Crow, 20 s", "A mat or a rug, and a pillow",
  "Same pose, longer.",
  ["Press the floor away, shoulders forward of the wrists.", "Breathe slowly, small breaths.",
   "Two sets of 20 s.", "Next up: the tuck planche lean."],
  ["Collapsing into the shoulders"], ["extra-crow"])

# ---------------------------------------------------------------------------------- Leg raise
g("legraise", "Reverse crunch", "Floor",
  "On your back, hands by the sides or under the hips. Knees over the hips, bent at 90°.",
  ["Curl the pelvis off the floor, knees toward the chest.", "Lift the hips, not the legs.",
   "Lower slowly until the tailbone touches.", "Don't swing the legs for momentum."],
  ["Swinging the legs", "Lower back arching on the way down"], ["Reverse_Crunch"])
g("legraise", "Lying knee raise", "Floor",
  "On your back, hands under the hips or beside you. Legs hovering just off the floor.",
  ["Pull the knees to the chest, curling the pelvis.", "Lower the legs back to hover, not touching the floor.",
   "Lower back stays flat all rep.", "Slow in both directions."],
  ["Lower back lifting off", "Letting the feet rest on the floor"], ["Flat_Bench_Leg_Pull-In"], BAR)
g("legraise", "Lying leg raise", "Floor",
  "On your back, hands under the hips. Legs straight, hovering.",
  ["Lift the straight legs to vertical.", "Lower them to a hand above the floor, no lower.",
   "Press the lower back down the whole time.", "Bend the knees slightly if the back lifts."],
  ["Arching the lower back", "Dropping the legs fast"], ["Flat_Bench_Lying_Leg_Raise"], BAR)
g("legraise", "Slow leg raise", "Floor",
  "Same position.",
  ["Lift up in one second.", "Take four seconds to lower.", "Stop the lowering before the back lifts.", "Count out loud."],
  ["Rushing the lowering", "Lower back arching"], ["Flat_Bench_Lying_Leg_Raise"], BAR)
g("legraise", "V-up", "Floor",
  "Lie flat, arms overhead, legs straight.",
  ["Lift arms and legs together and meet over the hips.", "Touch the toes or the shins at the top.",
   "Lower back down with control, both together.", "Make the lower slower than the lift."],
  ["Using momentum", "Collapsing on the way down"], ["Jackknife_Sit-Up"], BAR)

# ---------------------------------------------------------------------------------- Handstand push-up (later)
g("hspu", "Pike push-up", "Floor",
  "Start in a downward-dog shape: hands on the floor, hips high.",
  ["Bend the elbows and lower the head to a spot in front of the hands: a triangle.", "Push back up until the arms are straight.",
   "Keep the hips high over the hands.", "Elbows point back, about 45°."],
  ["Hips dropping", "Elbows flaring"], ["Handstand_Push-Ups"], "Photo shows the handstand push-up, which this builds toward.")
g("hspu", "Feet-elevated pike push-up", "A chair or the sofa seat",
  "Feet on a chair seat or the sofa, hips high over the hands.",
  ["Same pike push-up, more weight on the shoulders.", "Head lowers between the hands.",
   "Push back up until the arms lock.", "Chair against a wall."],
  ["Hips drifting back", "Sinking into the shoulders"], ["Handstand_Push-Ups"], "Photo shows the handstand push-up, which this builds toward.")
g("hspu", "Wall handstand negative", "A bare wall, a cushion",
  "In the chest-to-wall hold, with a cushion on the floor under the head.",
  ["Lower the head toward the cushion over five seconds.", "Keep the body tight and the elbows about 45°.",
   "Touch the cushion, then walk down. Pushing up comes later.", "Three negatives per set."],
  ["Collapsing on the way down", "Elbows flaring"], ["Handstand_Push-Ups"], "Photo shows the handstand push-up, which this builds toward.")
g("hspu", "Partial wall HSPU", "A bare wall, a stack of books",
  "Chest-to-wall hold with a stack of books or a yoga block under the head.",
  ["Lower the head to the stack, then press back up.", "Take a few books away over the weeks.",
   "Keep the body tight.", "Stop when you can't keep a straight line."],
  ["Arching the back", "Kicking off the wall"], ["Handstand_Push-Ups"], "Photo shows the handstand push-up, which this builds toward.")
g("hspu", "Wall handstand push-up", "A bare wall and a mat",
  "Chest-to-wall hold, head just above the floor.",
  ["Lower until the head touches the floor lightly.", "Press back to straight arms.",
   "Full range every rep.", "Any pinch at the front of the shoulder: go back to pikes."],
  ["Bouncing off the head", "Banana back"], ["Handstand_Push-Ups"])

# ---------------------------------------------------------------------------------- Nordic curl (later)
g("nordic", "Single-leg Romanian deadlift", "Floor",
  "Stand on one leg, a slight bend in the knee. Hands on the hips or reaching toward the floor.",
  ["Hinge at the hips, back flat, the free leg reaching back.", "Lower until the torso is near horizontal.",
   "Stand up by pushing the floor away.", "Hold a wall or chair with one finger if you need balance."],
  ["Rounding the back", "Hips opening to the side"], [])
g("nordic", "Banded Nordic curl", "Band on the door anchor (high), a heavy sofa",
  "Kneel on a pillow with the heels hooked under a heavy sofa or bed. Loop a band from the top of the door around your chest, like a sling, to take some of the weight.",
  ["Body stays in one line from the knees to the head.", "Lower slowly forward until the band can't help any more.",
   "Pull yourself back up with the hamstrings and the band.", "Use a thicker band if it's too hard."],
  ["Bending at the hips", "Sofa moving"], ["Natural_Glute_Ham_Raise"],
  "Photo shows the glute-ham raise on a machine. At home your heels are held under a heavy sofa.")
g("nordic", "Nordic negative", "A heavy sofa, a pillow",
  "Kneel on a pillow, heels hooked under a heavy sofa or bed.",
  ["Lower forward as slowly as you can, body straight.", "Catch yourself on your hands near the floor.",
   "Push back to the start with the hands.", "Hamstrings stay sore for days at first, so go easy."],
  ["Folding at the hips", "Falling fast"], ["Natural_Glute_Ham_Raise"],
  "Photo shows the glute-ham raise on a machine. At home your heels are held under a heavy sofa.")
g("nordic", "Nordic curl", "A heavy sofa, a pillow",
  "Same set-up.",
  ["Lower forward under control, then pull back up with the hamstrings.", "Minimal hand help.",
   "Body straight from knees to head.", "Quality over reps."],
  ["Folding at the hips", "Pushing up off the floor with the hands"], ["Natural_Glute_Ham_Raise"],
  "Photo shows the glute-ham raise on a machine. At home your heels are held under a heavy sofa.")

# ---------------------------------------------------------------------------------- Planche (later)
g("planche", "Pseudo planche push-up", "Floor, the handles",
  "Push-up position with the hands by the hips, fingers turned out. The shoulders move forward of the hands.",
  ["Lean forward so the shoulders are past the hands.", "Lower the chest to the floor, elbows tight to the ribs.",
   "Push back up while holding the lean.", "Warm the wrists first."],
  ["Hips dropping", "Wrists hurting: use the handles"], ["Pushups"],
  "Photo shows the plain push-up. Here the hands sit by the hips and the shoulders lean forward.")
g("planche", "Planche lean", "Floor, the handles",
  "Push-up position, hands by the hips, fingers turned out.",
  ["Lean forward, shoulders ahead of the hands, arms straight.", "Push the floor away so the back rounds slightly.",
   "Stay on the toes.", "Hold for twenty seconds."],
  ["Bending the elbows", "Hips sagging"], ["Pushups"],
  "Photo shows the plain push-up. In the lean you stay at the top with the shoulders forward.")
g("planche", "Tuck planche", "Floor, the handles",
  "Hands by the hips, knees tucked toward the chest.",
  ["Lean forward until the feet come off the floor.", "Arms straight, back rounded, knees tight to the chest.",
   "Hold as long as the form lasts.", "A long road: weeks of leans first."],
  ["Bent arms", "Hips too high"], ["Pushups"], "Photo shows the plain push-up. The tuck planche has no photo.")

# ---------------------------------------------------------------------------------- Dragon flag (later)
g("dragon", "Tuck dragon flag", "A heavy sofa or bed, a mat",
  "Lie on the floor with the head by the leg of a heavy sofa or bed. Reach back and grip it with both hands behind the head.",
  ["Bend the knees tight to the chest and lift the hips and lower back off the floor.", "Body rests on the upper back and shoulders only.",
   "Hold with the abs, not the arms.", "Hold for five seconds."],
  ["Resting on the neck", "Letting the hips drop"], [])
g("dragon", "One-leg dragon flag", "A heavy sofa or bed, a mat",
  "Same set-up, one leg straight and one tucked.",
  ["Lift into the tuck, then extend one leg straight up.", "Hips stay up, body in a line from the shoulders.",
   "Alternate the straight leg.", "Five seconds each side."],
  ["Hips dropping", "Rushing the extension"], [])
g("dragon", "Dragon flag negative", "A heavy sofa or bed, a mat",
  "Same set-up. Start at the top with the body straight over the shoulders.",
  ["Lower the straight body toward the floor over five seconds.", "Keep it as one plank, hinging at the shoulders only.",
   "Stop just above the floor.", "Back to the start with a tuck and a lift."],
  ["Folding at the hips", "Dropping fast", "Resting on the neck"], [])
g("dragon", "Dragon flag", "A heavy sofa or bed, a mat",
  "Same set-up.",
  ["Lift into a straight body supported on the upper back and shoulders.", "Lower with a straight body to just above the floor.",
   "Lift again without bending at the hips.", "Three clean reps."],
  ["Hips piking", "Resting on the neck"], [])
