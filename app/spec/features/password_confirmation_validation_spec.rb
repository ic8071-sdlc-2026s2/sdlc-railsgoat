# frozen_string_literal: true
require "spec_helper"

# Regression coverage for app/assets/javascripts/validation.js, which is shared
# by the signup page and the account settings page. The two pages render the
# password fields with different ids (signup overrides them, account settings
# uses the Rails defaults), so the equalTo rule must not depend on an id.
#
# Unlike the specs in spec/vulnerabilities, this is not a training exercise:
# it must pass in both training and maintainer mode.
feature "client-side password confirmation validation", js: true do
  let(:normal_user) { UserFixture.normal_user }
  let(:new_email) { "new.user@metacorp.com" }

  before(:each) do
    UserFixture.reset_all_users
  end

  # validation.js is included at the bottom of both pages as a separate script,
  # so the form fields can exist before jQuery Validate has attached to the
  # form (noticeably on a cold asset cache). Wait for the validator instance
  # before interacting with the fields.
  def wait_for_validator
    expect(page).to have_css("#account_edit")
    page.document.synchronize do
      attached = page.evaluate_script("!!(window.jQuery && jQuery('#account_edit').data('validator'))")
      raise Capybara::ElementNotFound, "jQuery Validate not attached to #account_edit" unless attached
    end
  end

  # jQuery Validate runs the rules on blur, so move focus elsewhere after
  # filling in the confirmation field.
  def blur_to(selector)
    find(selector).click
  end

  def fill_signup_form(password:, confirmation:)
    visit "/signup"
    wait_for_validator
    fill_in "email", with: new_email
    fill_in "first_name", with: "New"
    fill_in "last_name", with: "User"
    fill_in "password", with: password
    fill_in "password_confirmation", with: confirmation
    blur_to("#email")
  end

  # The shared login helper returns as soon as the Login button is clicked.
  # Wait for the post-login redirect to land before navigating elsewhere,
  # otherwise the next visit races the login and gets bounced to the login page.
  def login_and_wait(user)
    login(user)
    expect(page).to have_current_path(home_dashboard_index_path)
  end

  def fill_account_settings_passwords(password:, confirmation:)
    login_and_wait(normal_user)
    visit "/users/#{normal_user.id}/account_settings"
    wait_for_validator
    within("#account_edit") do
      fill_in "user_password", with: password
      fill_in "user_password_confirmation", with: confirmation
    end
    blur_to("#user_email")
  end

  context "on the signup page" do
    scenario "matching passwords keep the submit button enabled and create the account" do
      fill_signup_form(password: "secret123", confirmation: "secret123")

      expect(page).not_to have_content("Please enter the same password as above")
      expect(page).to have_button("Create Account", disabled: false)

      click_on "Create Account"

      expect(page).not_to have_current_path("/signup")
      expect(User.find_by(email: new_email)).to be_present
    end

    scenario "a mismatched confirmation disables the submit button" do
      fill_signup_form(password: "secret123", confirmation: "secret124")

      expect(page).to have_content("Please enter the same password as above")
      expect(page).to have_button("Create Account", disabled: true)
    end

    scenario "a password shorter than 6 characters is rejected client-side" do
      fill_signup_form(password: "abcde", confirmation: "abcde")

      expect(page).to have_content("Your password must be at least 6 characters long")
      expect(page).to have_button("Create Account", disabled: true)
    end
  end

  context "on the account settings page" do
    scenario "matching passwords keep the submit button enabled" do
      fill_account_settings_passwords(password: "secret123", confirmation: "secret123")

      expect(page).not_to have_content("Please enter the same password as above")
      expect(page).to have_button("Submit", disabled: false)
    end

    scenario "a mismatched confirmation disables the submit button" do
      fill_account_settings_passwords(password: "secret123", confirmation: "secret124")

      expect(page).to have_content("Please enter the same password as above")
      expect(page).to have_button("Submit", disabled: true)
    end
  end
end
