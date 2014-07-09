#!/usr/bin/env ruby

require 'pp'
require 'optparse'

class CodeBox
    def initialize lines
        @data = {}
        lines.each_with_index do |line, y_idx|
            x_idx = 0
            line.each_char do |c|
                @data[[x_idx, y_idx]] = c
                x_idx += 1
            end
        end
        
        def self.[] x, y; @data[[x, y]] end
        def self.at pt; self[pt[0], pt[1]] end
        def self.set pt, what; @data[[pt[0], pt[1]]] = what end
        
        def self.r pt
            a = @data.select { |k, v| k[1] == pt[1] }
            xs = (a.keys.collect { |k| k[0] }).sort
            tmp = xs.select { |v| v > pt[0] }
            pt.replace [(tmp == [] ? xs.min : tmp.min), pt[1]]
            at pt
        end
        def self.l pt
            a = @data.select { |k, v| k[1] == pt[1] }
            xs = (a.keys.collect { |k| k[0] }).sort
            tmp = xs.select { |v| v < pt[0] }
            pt.replace [(tmp == [] ? xs.max : tmp.max), pt[1]]
            at pt
        end
        def self.d pt
            a = @data.select { |k, v| k[0] == pt[0] }
            ys = (a.keys.collect { |k| k[1] }).sort
            tmp = ys.select { |v| v > pt[1] }
            pt.replace [pt[0], (tmp == [] ? ys.min : tmp.min)]
            at pt
        end
        def self.u pt
            a = @data.select { |k, v| k[0] == pt[0] }
            ys = (a.keys.collect { |k| k[1] }).sort
            tmp = ys.select { |v| v < pt[1] }
            pt.replace [pt[0], (tmp == [] ? ys.max : tmp.max)]
            at pt
        end
    end
end # class CodeBox

class Stack
    attr_accessor :data
    def initialize data
        @data = data
        
        def self.pop cnt
            if cnt > @data.length; abort 'something smells fishy... (stack error)' end
            @data.pop cnt
        end
        
        def self.safe_single_pop; @data.pop end
        def self.push value; @data << value end
        
        @reg = nil
        def self.reg
            if @reg.is_nil?
                @reg = self.pop 1
            else
                self.push @reg
                @reg = nil
                ret
            end
        end
    end
end # class Stack

class Interpreter
    @@prng = Random.new
    @@stdout = $stdout
    
    @@mirrors = {
        '_'  => { 'r' => 'r', 'l' => 'l', 'u' => 'd', 'd' => 'u' },
        '|'  => { 'r' => 'l', 'l' => 'r', 'u' => 'u', 'd' => 'd' },
        '/'  => { 'r' => 'u', 'l' => 'd', 'u' => 'r', 'd' => 'l' },
        '\\' => { 'r' => 'd', 'l' => 'u', 'u' => 'l', 'd' => 'r' },
        '#'  => { 'r' => 'l', 'l' => 'r', 'u' => 'd', 'd' => 'u' },
    }    
    
    @@div_chk = lambda do |d|
        abort 'something smells fishy... (division by zero)' unless d != 0
    end
    
    @@ops = {
        # control flow
        '>' => lambda { |pt, dir, stks, box, cntl| dir.replace 'r' },
        '<' => lambda { |pt, dir, stks, box, cntl| dir.replace 'l' },
        'v' => lambda { |pt, dir, stks, box, cntl| dir.replace 'd' },
        '^' => lambda { |pt, dir, stks, box, cntl| dir.replace 'u' },
        'x' => lambda { |pt, dir, stks, box, cntl| dir.replace 'rlud'[@@prng.rand 4] },
        '!' => lambda { |pt, dir, stks, box, cntl| box.send dir, pt },
        '?' => lambda { |pt, dir, stks, box, cntl| v = stks[-1].safe_single_pop; box.send dir, pt unless !v.nil? and v != 0 },
        '.' => lambda { |pt, dir, stks, box, cntl| pt.replace stks[-1].pop 2 },
        # operators
        '+' => lambda { |pt, dir, stks, box, cntl| x, y = stks[-1].pop 2; stks[-1].push x + y },
        '-' => lambda { |pt, dir, stks, box, cntl| x, y = stks[-1].pop 2; stks[-1].push x - y },
        '*' => lambda { |pt, dir, stks, box, cntl| x, y = stks[-1].pop 2; stks[-1].push x * y },
        ',' => lambda { |pt, dir, stks, box, cntl| x, y = stks[-1].pop 2; @@div_chk.call y; stks[-1].push x.to_f / y.to_f },
        '%' => lambda { |pt, dir, stks, box, cntl| x, y = stks[-1].pop 2; @@div_chk.call y; stks[-1].push x % y },
        '=' => lambda { |pt, dir, stks, box, cntl| x, y = stks[-1].pop 2; stks[-1].push (x == y ? 1 : 0) },
        ')' => lambda { |pt, dir, stks, box, cntl| x, y = stks[-1].pop 2; stks[-1].push (x > y ? 1 : 0) },
        '(' => lambda { |pt, dir, stks, box, cntl| x, y = stks[-1].pop 2; stks[-1].push (x < y ? 1 : 0) },
        # strings
        '\'' => lambda { |pt, dir, stks, box, cntl| while ((a = box.send dir, pt) != '\'') do; stks[-1].push a.ord end },
        '"'  => lambda { |pt, dir, stks, box, cntl| while ((a = box.send dir, pt) != '"') do; stks[-1].push a.ord end },
        # stack manipulation
        ':' => lambda { |pt, dir, stks, box, cntl| stks[-1].push stks[-1].data[-1] },
        '~' => lambda { |pt, dir, stks, box, cntl| stks[-1].pop 1 },
        '$' => lambda { |pt, dir, stks, box, cntl| x, y = stks[-1].pop 2; stks[-1].push y; stks[-1].push x },
        '@' => lambda { |pt, dir, stks, box, cntl| x, y, z = stks[-1].pop 3; stks[-1].push z; stks[-1].push x; stks[-1].push y },
        '}' => lambda { |pt, dir, stks, box, cntl| stks[-1].data.rotate! 1 },
        '{' => lambda { |pt, dir, stks, box, cntl| stks[-1].data.rotate! -1 },
        'r' => lambda { |pt, dir, stks, box, cntl| stks[-1].data.reverse! },
        'l' => lambda { |pt, dir, stks, box, cntl| stks[-1].push stks[-1].data.length },
        '[' => lambda { |pt, dir, stks, box, cntl| stks << (Stack.new stks[-1].pop stks[-1].pop 1) },
        ']' => lambda { |pt, dir, stks, box, cntl| stks[-1].data.concat stks.pop.data },
        # io
        'o' => lambda { |pt, dir, stks, box, cntl| @@stdout.write (stks[-1].pop 1)[0].round.chr },
        'n' => lambda { |pt, dir, stks, box, cntl| @@stdout.write (stks[-1].pop 1)[0].to_s },
        'i' => lambda { |pt, dir, stks, box, cntl| stks[-1].push (cntl[:ibuf].empty? ? -1 : cntl[:ibuf][0].ord); cntl[:ibuf] = cntl[:ibuf][1..-1] unless cntl[:ibuf].length < 2 },
        # reflection
        'g' => lambda { |pt, dir, stks, box, cntl| stks[-1].push (box.at stks[-1].pop 2).ord },
        'p' => lambda { |pt, dir, stks, box, cntl| box.set (stks[-1].pop 2), (stks[-1].pop 1) },
        # miscellaneous
        '&' => lambda { |pt, dir, stks, box, cntl| stks[-1].reg },
        ';' => lambda { |pt, dir, stks, box, cntl| cntl[:done] = true },
        ' ' => lambda { |pt, dir, stks, box, cntl| }
    }
    
    @@mirrors.each do |k, v|
        @@ops.merge! k => lambda { |pt, dir, stks, box, cntl| dir.replace v[dir] }
    end
    
    (0..9).to_a.each do |v|
        @@ops.merge! v.to_s => lambda { |pt, dir, stks, box, cntl| stks[-1].push v }
    end
    
    ('a'..'f').to_a.each do |v|
        @@ops.merge! v => lambda { |pt, dir, stks, box, cntl| stks[-1].push (v.ord - 0x57) }
    end
    
    def initialize lines, options
        @box = CodeBox.new lines.collect { |line| line.chomp.chomp }
        
        @pt = [0, 0]
        @dir = 'r'
        @stks = []
        @stks << (Stack.new [])
        @cntl = {
            :ibuf => options[:stdin],
            :done => false,
        }
        
        
        op = @box.at @pt
        while !@cntl[:done] do
            op = ' ' if op.nil?
            if options[:debug] >= 3; puts op end
            func = @@ops[op]
            abort 'something smells fishy... (invalid instruction)' if func.nil?
            func.call @pt, @dir, @stks, @box, @cntl
            op = @box.send @dir, @pt
        end
    end
end # class Interpreter


options = {}
optparse = OptionParser.new do |opts|
    opts.banner = "fish.rb <options> <files>"
    
    opts.on '-h', '--help', 'Display help' do; puts opts; exit end
    options[:debug] = 0
    opts.on '-d [level]', '--debug [level]', 'Print debug messages (max of 3, defaults to 1)' do |opt|
        options[:debug] = opt.to_i || options[:debug] = 1
    end
    options[:stdin] = ""
    opts.on '-s str', '--stdin str', 'Stdin for fish script' do |opt|; options[:stdin] = opt end
    opts.on '-r file', '--redir-stdout file', 'Redirect fish stdout to file' do |opt|
        options[:stdout] = File.open opt, 'w'
    end
end.parse!

Interpreter.new (IO.readlines ARGV.shift), options
