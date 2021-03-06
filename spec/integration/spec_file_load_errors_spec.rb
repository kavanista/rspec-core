require 'support/aruba_support'
require 'support/formatter_support'

RSpec.describe 'Spec file load errors' do
  include_context "aruba support"
  include FormatterSupport

  let(:failure_exit_code) { rand(97) + 2 } # 2..99

  if RSpec::Support::Ruby.jruby_9000?
    let(:spec_line_suffix) { ":in `<top>'" }
  elsif RSpec::Support::Ruby.jruby?
    let(:spec_line_suffix) { ":in `(root)'" }
  elsif RUBY_VERSION == "1.8.7"
    let(:spec_line_suffix) { "" }
  else
    let(:spec_line_suffix) { ":in `<top (required)>'" }
  end

  before do
    # get out of `aruba` sub-dir so that `filter_gems_from_backtrace 'aruba'`
    # below does not filter out our spec file.
    expect(dirs.pop).to eq "aruba"

    clean_current_dir

    RSpec.configure do |c|
      c.filter_gems_from_backtrace "aruba"
      c.backtrace_exclusion_patterns << %r{/rspec-core/spec/} << %r{rspec_with_simplecov}
      c.failure_exit_code = failure_exit_code
    end
  end

  it 'nicely handles load-time errors in user spec files' do
    write_file_formatted "1_spec.rb", "
      boom

      RSpec.describe 'Calling boom' do
        it 'will not run this example' do
          expect(1).to eq 1
        end
      end
    "

    write_file_formatted "2_spec.rb", "
      RSpec.describe 'No Error' do
        it 'will not run this example, either' do
          expect(1).to eq 1
        end
      end
    "

    write_file_formatted "3_spec.rb", "
      boom

      RSpec.describe 'Calling boom again' do
        it 'will not run this example, either' do
          expect(1).to eq 1
        end
      end
    "

    run_command "1_spec.rb 2_spec.rb 3_spec.rb"
    expect(last_cmd_exit_status).to eq(failure_exit_code)
    output = normalize_durations(last_cmd_stdout)
    expect(output).to eq unindent(<<-EOS)

      An error occurred while loading ./1_spec.rb.
      Failure/Error: boom

      NameError:
        undefined local variable or method `boom' for main:Object
      # ./1_spec.rb:1#{spec_line_suffix}

      An error occurred while loading ./3_spec.rb.
      Failure/Error: boom

      NameError:
        undefined local variable or method `boom' for main:Object
      # ./3_spec.rb:1#{spec_line_suffix}


      Finished in n.nnnn seconds (files took n.nnnn seconds to load)
      0 examples, 0 failures
    EOS
  end
end
