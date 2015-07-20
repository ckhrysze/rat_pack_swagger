class SwaggerObject
  instance_methods.each do |m|
    unless m =~ /^__/ || [:inspect, :instance_eval, :object_id].include?(m)
      undef_method m
    end
  end

  def initialize(*args, **kwargs, &block)
    if args.count > 0 && (!kwargs.empty? || block_given?)
      raise "Cannot give both unnamed arguments AND named arguments or block to Swagger parameter '#{m}'."
    elsif block_given?
      @obj = kwargs unless kwargs.empty?
      instance_eval &block
    elsif !kwargs.empty?
      @obj = kwargs
    elsif args.count > 0
      @obj = [*args]
    else
      raise "Cannot create SwaggerObject with no arguments."
    end
  end

  def add(*args, **kwargs)
    @obj ||= []
    if !@obj.is_a?(Array)
      raise "Swagger object must be an array to append data '#{item}'"
    elsif args.count > 0
      @obj << [*args, kwargs]
    else
      @obj << kwargs
    end
  end

  def method_missing(m, *args, **kwargs, &block)
    @obj ||= {}
    if block_given?
      @obj[m] = SwaggerObject.new(**kwargs, &block).to_h
    elsif !kwargs.empty?
      @obj[m] = SwaggerObject.new(**kwargs).to_h
    elsif args.count > 1
      @obj[m] = [*args]
    elsif args.count == 1
      @obj[m] = args[0]
    else
      raise "Cannot give zero arguments to Swagger key '#{m}'"
    end
  end

  def to_h
    @obj
  end
end
