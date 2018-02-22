 ; Hill traversing in the model is obtained from Railsback and Grimm's 2005 textbook on Agent-based Modelling

;;; VARIABLE DEFINITION AND CLASS ASSIGNMENTS
globals [
          year ; Storing the current year that it is on
          all-turtle-locations ; Storing locations of all turtle/birds locations in the model and the original values of the raster for restoration purposes.
]
patches-own [
  temperature
]
turtles-own [
  speed                  ; Speed the turtle can travel at
  at-happy-elev?         ; Am I at my actual maximum elevation?
  list-locations         ; Where the specific bird has been
]


to-report random-range [minimum maximum]

  let r (minimum - maximum)
  let rr random r
  report rr + minimum

end

to setup
  ca
  ; Begins at year 0 - for when it reaches end of year and needs to start over again.
  set year 0
  ; Begin filling our list of locations where the bird has been
  ; Read in the surface file for the specified starting date.
  read-surface start-date
  set all-turtle-locations []
  set all-turtle-locations []
  ; Add birds to surface - amount specified by slider
  crt number-of-birds
  [
    set size 5
    ; set initial location of butterflies
    let starting-x (random-range 120 135)
    let starting-y (random-range 60 75)

    set all-turtle-locations lput (list starting-x starting-y -9999) all-turtle-locations

    setxy starting-x starting-y
    set speed 2
    set heading 90
    set color green

  ] ; End of bird creation

  ; Initialize the empty list for each turtle
  ask turtles [set list-locations []
               set color one-of (remove yellow (remove red (remove orange base-colors))) ]

  show all-turtle-locations
  reset-ticks

end   ; End of setup procedure

to write-locations [location-list output-file-location]
  file-open output-file-location
  file-print "NEWRUN"
  foreach location-list
  [ x -> file-write (item 0 x) file-write (item 1 x)
    file-print ""]

  file-close



end


to read-surface [julian-date]
  set julian-date (julian-date - 1)

  ; Read in initial surface data
  file-open (word "/media/alex/AJMCVITT/nlogo/" julian-date ".txt") ; Open the IO stream for the initial surface data

  show julian-date
  while [not file-at-end?]
  [ let next-X file-read
    let next-Y file-read
    let next-temperature file-read
    let loc 0
    ; Apply climate change variable if specified in interface
    ifelse climate-change != "None"[
      ifelse climate-change = "Additive"[
        set next-temperature next-temperature + climate-change-additive
        ask patch next-X next-Y [set temperature next-temperature]
        reassign-patches next-X next-Y next-temperature
      ][
        ifelse climate-change = "Multiply" [
          set next-temperature next-temperature * climate-change-multiply
          ask patch next-X next-Y [set temperature next-temperature]
          reassign-patches next-X next-Y next-temperature
        ][
          carefully [ ; Does not work with the really big NoData values for the ocean with exponents.
            set next-temperature next-temperature ^ climate-change-exponent
            ask patch next-X next-Y [set temperature next-temperature]
            reassign-patches next-X next-Y next-temperature
          ] [
            ask patch next-X next-Y [set temperature -9999]
            reassign-patches next-X next-Y -9999
          ] ; End of inner multiply/exponential if else
        ]; End of try-catch
      ]; End of inner if else additive/multiply
    ][ ; Don't apply climate change - read in

      ask patch next-X next-Y [set temperature next-temperature]
      reassign-patches next-X next-Y next-temperature
     ]; End of climate change if else
  ] ; End of reading file data to elevation variable
  file-close ; Close IO stream

  ; Update the surface visually - has no effect on model running but is good visual indicator of things working
  ask patches
  [ set pcolor scale-color orange temperature -30 110 ]

  ; Go through list of where bird has been and set them to really low values - Done after visual surface update to have it invisible.
  ;foreach list-locations
  ;[ x -> ask patch (item 0 x) (item 1 x) [set temperature -9999] ]


end ; end of read-surface procedure


to go ; This is the master schedule
  ask turtles
  [ set speed 1
    ;set visible-neighbors (other turtles in-cone vision-distance vision-cone)
    ;ifelse any? visible-neighbors
    ;  [ adjust ]
    ;  [ set happy? true]
    ;recolor
    move
    if temperature >= max-surface [stop]
  ]
  ; Update the tick counter
  tick
  ; Programatically change the temperature surface if specified
  if change-surface
  [ if ticks mod movement-between-date-changes = 0
    [
      let filen ticks
      if (round (ticks / movement-between-date-changes) + start-date) > 364
      [
        set filen (round (ticks / movement-between-date-changes) + start-date) - 365
      ]

      read-surface filen
    ]
  ]
  ; End simulation after n ticks
  if ticks >= max-ticks
  [
    stop
  ]

end ; end of go schedule

;; Reassigns patch value at x y to v.
to reassign-patches[x y v]
  ask patch x y [set temperature v]
end

to re [target-x target-y indice-x indice-y v c]

  if target-x = indice-x and target-y = indice-y
  [ let list-insert (list target-x target-y v)
    set all-turtle-locations replace-item c all-turtle-locations list-insert ]
end

to update-preserved-list[x y v]
  let c 0
  foreach all-turtle-locations
  [ i ->  (re x y (item 0 i) (item 1 i) v c)
    set c (c + 1) ]
end




to move ; This is the butterfly move procedure, in turtle context
        ; Decide whether to move to the highest
        ; surrounding patch with probability q
  ; Only move if the maximum temperature has not been reached.

  if list-locations = 0 [set list-locations (list (list xcor ycor))]
  if at-happy-elev? != True
  [ ifelse temperature < max-surface
    [ ifelse track-movement
      [ pen-down ]
      [ pen-up ]
      ; Assign current temperature to temporary value
      let this-elev temperature
      ; TODO reset patches using the all-turtles-location list
      foreach all-turtle-locations
      [ x -> (reassign-patches (item 0 x) (item 1 x) (item 2 x))]

      ; Set the path of this bird to be very low values so the bird does not traverse.
      foreach list-locations
      [ x -> (reassign-patches (item 0 x) (item 1 x) -9999)]

      ; Store this location in the list of locations so that the bird avoids going back to where it was
      set list-locations lput (list xcor ycor) list-locations
      set all-turtle-locations lput (list xcor ycor this-elev) all-turtle-locations

      ; Get the bird out of the ocean if it flew there
      if temperature < -900
      [ uphill temperature ]

      ; Migrate deterministically
      ifelse random-float 1 < q
        [ uphill temperature ]
        [ move-to one-of neighbors ]
      foreach all-turtle-locations
      [ x -> (reassign-patches (item 0 x) (item 1 x) (item 2 x))]
    ][set at-happy-elev? True
      if write-path-to-file
      [ write-locations list-locations "out2.txt" ]
     ] ;

  ]; End of if at happy elevation check.

end ; end of move procedure
@#$#@#$#@
GRAPHICS-WINDOW
3
10
1187
369
-1
-1
2.69231
1
10
1
1
1
0
1
1
1
0
436
-129
0
0
0
1
ticks
30.0

BUTTON
1186
11
1309
44
NIL
setup\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1186
44
1309
77
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
601
369
754
402
track-movement
track-movement
0
1
-1000

SLIDER
302
436
601
469
movement-between-date-changes
movement-between-date-changes
0
100
70.0
1
1
NIL
HORIZONTAL

SLIDER
2
369
307
402
start-date
start-date
1
365
365.0
1
1
NIL
HORIZONTAL

SLIDER
754
415
787
507
climate-change-additive
climate-change-additive
0
20
7.2
0.2
1
NIL
VERTICAL

SLIDER
788
415
821
507
climate-change-multiply
climate-change-multiply
0
3
1.8
0.05
1
NIL
VERTICAL

SWITCH
602
435
754
468
change-surface
change-surface
0
1
-1000

SLIDER
2
402
305
435
max-ticks
max-ticks
0
3000
2000.0
1
1
NIL
HORIZONTAL

MONITOR
1186
76
1309
121
Date
((start-date + round ticks / movement-between-date-changes) mod 364)
17
1
11

CHOOSER
753
370
861
415
climate-change
climate-change
"None" "Additive" "Multiply" "Exponent"
0

TEXTBOX
758
506
861
524
ADD  MULT  EXP
12
0.0
1

SLIDER
2
435
302
468
max-surface
max-surface
-20
120
95.4
0.1
1
NIL
HORIZONTAL

SLIDER
302
369
600
402
q
q
0
1
0.7
0.05
1
NIL
HORIZONTAL

TEXTBOX
353
385
551
415
Higher = follow warmth more
12
0.0
1

SLIDER
824
415
857
507
climate-change-exponent
climate-change-exponent
0.1
5
0.1
0.1
1
NIL
VERTICAL

SWITCH
602
402
755
435
write-path-to-file
write-path-to-file
1
1
-1000

SLIDER
302
402
601
435
number-of-birds
number-of-birds
1
40
4.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)


## HOW TO CITE

For the Flocking V Model

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilkerson-Jerde, M., Stonedahl, F. and Wilensky, U. (2009).  NetLogo Flocking Vee Formations model.  http://ccl.northwestern.edu/netlogo/models/FlockingVeeFormations.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="80" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="max-surface">
      <value value="68.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="movement-between-date-changes">
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="change-surface">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="starty">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start-date">
      <value value="54"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="track-movement">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="climate-change-multiply">
      <value value="1.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="climate">
      <value value="&quot;Multiply&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="climate-change-additive">
      <value value="9.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="startx">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="q">
      <value value="0.7"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
