# -----------------------------------------------------------------------------
# seeds.do - re-run the seed-dependent tests with several random seeds
#
# In the QuestaSim transcript (GUI), from the folder that contains `work`:
#     do sim/seeds.do
# (use the correct path to this file if your working folder is different)
#
# Results go to the transcript and to seed_results.txt in the working folder.
# -----------------------------------------------------------------------------

set seeds {1 2 3 4 5}

set tests {
  {tb_regfile_singlebit_fullcov  ""}
  {tb_regfile_mulbit_random      "+NUM_FAULTS=200"}
  {tb_regfile_bitflip_random     "+NUM_FAULTS=1000"}
}

set out [open "seed_results.txt" w]

foreach t $tests {
  set top  [lindex $t 0]
  set args [lindex $t 1]
  foreach s $seeds {
    echo "########## $top  seed=$s ##########"
    puts $out "########## $top  seed=$s ##########"
    transcript file seed_tmp.log
    if {$args eq ""} {
      vsim -onfinish stop -sv_seed $s $top
    } else {
      vsim -onfinish stop -sv_seed $s $args $top
    }
    run -all
    transcript file ""
    # copy the summary lines into seed_results.txt
    set f [open "seed_tmp.log" r]
    while {[gets $f line] >= 0} {
      if {[regexp {Activated|Escapes|False detections|Functional coverage|TEST} $line]} {
        puts $out $line
      }
    }
    close $f
    quit -sim
  }
}

close $out
echo "Done - results written to seed_results.txt"
