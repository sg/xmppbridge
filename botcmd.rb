#==================================================================
# Botcmd Class 
#
# Commands that are set to :type => :private are only usable by
# admins.  If set to :type => :public then anyone can use them.
#
# Copyright 2009 by Steve Gibson
# steve@stevegibson.com (xmpp and email)
#
# This is free software.  You can redistribute it and/or
# modify it under the terms of the BSD license.  See
# LICENSE for more details.
#==================================================================
class Botcmd

  attr_accessor :name, :type, :code, :return, :helptxt

  def initialize(elements)
    @elements = elements
    @name = @elements[:name]
    @type = @elements[:type]
    @code = @elements[:code]
    @return = @elements[:return]
    @helptxt = @elements[:helptxt]
  end

  def to_s
    "#{@name} (#{@type})" 
  end

  def self.get_help(name)
    found = nil
    ObjectSpace.each_object(Botcmd) { |obj|
      found = obj if obj.name == name
      found.helptxt
    }
  end

  def exec
    if @return
      eval(@code).to_s
    else
      eval(@code)
    end
  end
     
end




