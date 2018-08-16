require 'rails_helper'

describe PrettyText do

  it 'renders a video' do
    cooked = PrettyText.cook <<~MD
      [video=1234]
    MD

    expect(cooked).to include('class="brightcove-container"')
    expect(cooked).to include('data-video-id="1234"')
  end
end
