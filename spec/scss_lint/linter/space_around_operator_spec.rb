require 'spec_helper'

describe SCSSLint::Linter::SpaceAroundOperator do
  let(:linter_config) { { 'style' => style } }

  context 'when one space is preferred' do
    let(:style) { 'one_space' }

    context 'when no properties exist' do
      let(:scss) { <<-SCSS }
        p {
        }
      SCSS

      it { should_not report_lint }
    end

    context 'when values without infix operators exist' do
      let(:scss) { <<-SCSS }
        p {
          margin: 5px;
        }
      SCSS

      it { should_not report_lint }
    end

    context 'when values with properly-spaced infix operators exist' do
      let(:scss) { <<-SCSS }
        $x: 2px + 2px;

        p {
          margin: 5px + 5px;
        }
      SCSS

      it { should_not report_lint }
    end

    context 'when numeric values with infix operators exist' do
      let(:scss) { <<-SCSS }
        p {
          margin: 5px+5px;
          margin: 5px  +  5px;
          margin: 4px*2;
          margin: 20px%3;
          font-family: sans-+serif;
        }

        $x: 10px+10px;
        $x: 20px-10px;
      SCSS

      it { should report_lint line: 2 }
      it { should report_lint line: 3 }
      it { should report_lint line: 4 }
      it { should report_lint line: 5 }
      it { should report_lint line: 6 }
      it { should report_lint line: 9 }
      it { should report_lint line: 10 }
    end

    context 'when numeric values with multiple infix operators exist' do
      let(:scss) { <<-SCSS }
        p {
          margin: 5px*2+8px;
        }
      SCSS

      it { should report_lint line: 2, count: 2 }
    end

    context 'when if nodes with comparison infix operators exist' do
      let(:scss) { <<-SCSS }
        p {
          @if 3==2 {
            margin: 5px;
          }

          @if 5>4 {
            margin: 5px;
          }
        }
      SCSS

      it { should report_lint line: 2 }
      it { should report_lint line: 6 }
    end

    context 'when values containing multiple operators exist' do
      let(:scss) { <<-SCSS }
        p {
          margin: 2px+8px 18px+12px;
        }
      SCSS

      it { should report_lint line: 2, count: 2 }
    end

    context 'when a function call contains a value with infix operators' do
      let(:scss) { <<-SCSS }
        p {
          margin: some-function(2em+1em);
        }
      SCSS

      it { should report_lint line: 2 }
    end

    context 'when mixin include contains a value with infix operators' do
      let(:scss) { <<-SCSS }
        p {
          @include some-mixin(4em-2em);
        }
      SCSS

      it { should report_lint line: 2 }
    end

    context 'when string contains an infix operator' do
      let(:scss) { <<-SCSS }
        p {
          content: func("4em-2em");
        }
      SCSS

      it { should_not report_lint }
    end

    context 'when string contains an interpolated infix operator' do
      let(:scss) { <<-SCSS }
        p {
          content: "There are \#{11+1} months."
        }
      SCSS

      it { should report_lint line: 2 }
    end

    context 'when values with non-evaluated operations exist' do
      let(:scss) { <<-SCSS }
        $my-variable: 10px;

        p {
          font: 12px/10px;
          margin: 2em-1em;
          padding: $my-variable;
        }
      SCSS

      it { should_not report_lint }
    end

    context 'when values with proper division operations exist' do
      let(:scss) { <<-SCSS }
        $x: 20px;
        p {
          width: $x/2;
          width: round(1.5)/2;
          width: (50px/2);
          width: 10px + 20px/2;
        }
      SCSS

      it { should report_lint line: 3 }
      it { should report_lint line: 4 }
      it { should report_lint line: 5 }
      it { should report_lint line: 6 }
    end
  end
  context 'when one space is preferred' do
    let(:style) { 'no_space' }

    context 'when values with single-spaced infix operators exist' do
      let(:scss) { <<-SCSS }
        $x: 2px + 2px;

        p {
          margin: 5px + 5px;
          width: 5px   +       5px;
        }
      SCSS

      it { should report_lint line: 1 }
      it { should report_lint line: 4 }
      it { should report_lint line: 5 }
    end

    context 'when values with no-spaced infix operators exist' do
      let(:scss) { <<-SCSS }
        $x: 2px+2px;

        p {
          margin: 5px+5px;
        }
      SCSS

      it { should_not report_lint }
    end
  end
end
