patches-own [ read-temp ]

turtles-own [
  flockmates         ;; agentset of nearby turtles
  nearest-neighbor   ;; closest one of our flockmates
  readyteam? ;; enough friends to migrate
]
  extensions [gogo]

globals [
  serial-port ;; different on different operating systems
]

to setup
  clear-all
  ask patches [set pcolor SKY ]
  crt population
    [ set color yellow - 2 + random 7  ;; random shades look nice
      set size 1.5  ;; easier to see
      setxy random-xcor random-ycor ]
  reset-ticks
   ifelse length (gogo:ports) > 0
    [ set serial-port user-one-of "Select a port:" gogo:ports ]
    [ user-message "There is a problem with the connection. Check if the board is on, and if the cable is connected. Otherwise, try to quit NetLogo, power cycle the GoGo Board, and open NetLogo again. For more information on how to fix connection issues, refer to the NetLogo documentation or the info tab of this model"
      stop ]
  gogo:open serial-port
  repeat 5
  [ if not gogo:ping
    [ user-message "There is a problem with the connection. Check if the board is on, and if the cable is connected. Otherwise, try to quit NetLogo, power cycle the GoGo Board, and open NetLogo again. For more information on how to fix connection issues, refer to the NetLogo documentation or the info tab of this model"] ]
  gogo:talk-to-output-ports [ "a" "b" "c" "d"]
end 

to test-connection
  carefully
  [ ifelse not gogo:ping
    [ user-message "There is a problem with the connection. Check if the board is on, and if the cable is connected. Otherwise, try to quit NetLogo, power cycle the GoGo Board, and open NetLogo again. For more information on how to fix connection issues, refer to the NetLogo documentation or the info tab of this model" ]
    [ user-message "GoGo Board connected and working!" ] ]
  [ user-message error-message 
    stop ]
end 


; Public Domain:
; To the extent possible under law, Uri Wilensky has waived all
; copyright and related or neighboring rights to this model.

to go
  let temp gogo:sensor 3
  ask turtles [ flock ]
  ;; the following line is used to make the turtles
  ;; animate more smoothly.
  repeat 5 [ ask turtles [ fd 0.2 ] display ]
  ;; for greater efficiency, at the expense of smooth
  ;; animation, substitute the following line instead:
  ;;   ask turtles [ fd 1 ]
  tick
end 

;;to coolerbox 
  ;;set pcolor black
;;end

to migrate
    let temp gogo:sensor 3
  ask patches with [pxcor > 0  and pxcor < 16 and pycor > -8  and pycor < 8 ] [
    set pcolor black 
    set read-temp temp 
    if read-temp > 600 and read-temp < 620 ;; cool
    [ ask turtles-here [ set color violet - 2 + random 4 flock ] ]
    if read-temp > 620 ;; coldest
    [ ask turtles-here [set color white rt 45] ]
    if read-temp < 600 ;; hot
    [ ask turtles-here [set color red - 2 + random 4 scatter ] ]
  ]
end 

to goteam
;;  set readyteam? count flockmates >= ( 2 )
  set readyteam? count flockmates >= ( 2 )
  ask turtles with [ readyteam? ] 
  [set heading 180]
  ask turtles with [ not readyteam? ]
  [flock]
end 

to scatter
 set heading random 360
 rt 40
end 

to flock;; turtle procedure
  find-flockmates
  if any? flockmates
    [ find-nearest-neighbor
      ifelse distance nearest-neighbor < minimum-separation
        [ separate ]
        [ align
          cohere ] ]
end 

to find-flockmates  ;; turtle procedure
  set flockmates other turtles in-radius vision
end 

to find-nearest-neighbor ;; turtle procedure
  set nearest-neighbor min-one-of flockmates [distance myself]
end 

;;; SEPARATE

to separate  ;; turtle procedure
  turn-away ([heading] of nearest-neighbor) max-separate-turn
end 

;;; ALIGN

to align  ;; turtle procedure
  turn-towards average-flockmate-heading max-align-turn
end 

to-report average-flockmate-heading  ;; turtle procedure
  ;; We can't just average the heading variables here.
  ;; For example, the average of 1 and 359 should be 0,
  ;; not 180.  So we have to use trigonometry.
  let x-component sum [dx] of flockmates
  let y-component sum [dy] of flockmates
  ifelse x-component = 0 and y-component = 0
    [ report heading ]
    [ report atan x-component y-component ]
end 

;;; COHERE

to cohere  ;; turtle procedure
  turn-towards average-heading-towards-flockmates max-cohere-turn
end 

to-report average-heading-towards-flockmates  ;; turtle procedure
  ;; "towards myself" gives us the heading from the other turtle
  ;; to me, but we want the heading from me to the other turtle,
  ;; so we add 180
  let x-component mean [sin (towards myself + 180)] of flockmates
  let y-component mean [cos (towards myself + 180)] of flockmates
  ifelse x-component = 0 and y-component = 0
    [ report heading ]
    [ report atan x-component y-component ]
end 


;;; HELPER PROCEDURES

to turn-towards [new-heading max-turn]  ;; turtle procedure
  turn-at-most (subtract-headings new-heading heading) max-turn
end 

to turn-away [new-heading max-turn]  ;; turtle procedure
  turn-at-most (subtract-headings heading new-heading) max-turn
end 

;; turn right by "turn" degrees (or left if "turn" is negative),
;; but never turn more than "max-turn" degrees

to turn-at-most [turn max-turn]  ;; turtle procedure
  ifelse abs turn > max-turn
    [ ifelse turn > 0
        [ rt max-turn ]
        [ lt max-turn ] ]
    [ rt turn ]
end 


; Copyright 1998 Uri Wilensky.
; See Info tab for full copyright and license.

;; Retrieved from http://modelingcommons.org/browse/one_model/3503#model_tabs_browse_procedures 
;; posted by Natalia Smirnov 
;;  http://modelingcommons.org/?id=530
;; Citations 
;; 
;;    Wilensky, U. (1998). NetLogo Flocking model. http://ccl.northwestern.edu/netlogo/models/Flocking. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.
;;     Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

