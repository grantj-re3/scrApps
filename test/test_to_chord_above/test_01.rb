#
# File:		test_01.rb
# Author:	Grant Jackson
# Package:	N/A
# Environment:	Ruby 2.0.0
#
# Copyright (C) 2014
# Licensed under GPLv3. GNU GENERAL PUBLIC LICENSE, Version 3, 29 June 2007
# http://www.gnu.org/licenses/
#
##############################################################################

##############################################################################
# Extend this class by adding test methods
##############################################################################
class ChordLyricLineParts
 
  ############################################################################
  def self.test_pad
    tests = [
      # 1 arg
      "pad(2)",

      # 2 args
      "pad(2, 'Four')",
      "pad(-1, 'Four')",
      "pad(2, '')",
      "pad(1, nil)",

      # Return condition 1
      "pad(0)",
      "pad(-5, 'Four')",

      # Return condition 2
      "pad(2, 'Four', '*')",
      "pad(3, nil, '*', '%', -9)",

      # Return condition 3
      "pad(3, nil, '*', '%', 4)",
      "pad(3, nil, '*', '%', 3)",

      # Return condition 4
      "pad(3, nil, '*', '%', 2)",
      "pad(3, nil, '*', '%', 1)",
    ]

    puts "Test self.pad()"
    puts "==============="

    tests.each{|test|
      puts "\n" + "-" * 10 + test + "-" * 10
      puts " 123456789" * 2
      puts "<#{eval test}>"
    }
  end

end

