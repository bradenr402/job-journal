require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "should get edit" do
    get settings_url
    assert_response :success
  end

  test "should get edit with a tab param" do
    get settings_url(tab: "auto_archiving")
    assert_response :success
  end

  test "should render nested radio setting names and stable ids" do
    get settings_url(tab: "filters")

    assert_select "label[for='filters_job_leads']", text: "Default Job Leads Filter"
    assert_select "input[name='settings[filters][job_leads]']", 3
    assert_select "input#filters_job_leads_all[name='settings[filters][job_leads]']"
  end

  test "should fall back to default tab for an invalid tab param" do
    get settings_url(tab: "bogus")
    assert_response :success
  end

  test "should update only submitted settings without clobbering others" do
    @user.update_settings(filters: { notes: "archived" })

    patch settings_url(tab: "goals"), params: { settings: { goals: { weekly_applications: "15" } } }

    assert_redirected_to settings_path(tab: "goals")
    @user.reload
    assert_equal 15, @user.get_setting(:goals, :weekly_applications)
    assert_equal "archived", @user.get_setting(:filters, :notes)
  end

  test "should redirect preserving the submitted tab" do
    patch settings_url(tab: "follow_ups"), params: { settings: { follow_ups: { application_days: "9" } } }

    assert_redirected_to settings_path(tab: "follow_ups")
    assert_equal 9, @user.reload.get_setting(:follow_ups, :application_days)
  end

  test "should update nested settings from submitted form params" do
    patch settings_url(tab: "auto_archiving"), params: {
      settings: {
        archiving: {
          rejected: { enabled: "false" },
          inactive: { enabled: "true", after_days: "30" },
          stale: { enabled: "true", archive_after_days: "45" }
        }
      }
    }

    assert_redirected_to settings_path(tab: "auto_archiving")
    @user.reload
    assert_equal false, @user.get_setting(:archiving, :rejected, :enabled)
    assert_equal true, @user.get_setting(:archiving, :inactive, :enabled)
    assert_equal 30, @user.get_setting(:archiving, :inactive, :after_days)
    assert_equal 45, @user.get_setting(:archiving, :stale, :archive_after_days)
  end

  test "should ignore invalid submitted values without persisting them" do
    @user.update_settings(filters: { job_leads: "active" })
    @user.update_settings(goals: { weekly_applications: 12 })

    patch settings_url(tab: "filters"), params: {
      settings: {
        filters: { job_leads: "bogus" },
        goals: { weekly_applications: "-1" }
      }
    }

    assert_redirected_to settings_path(tab: "filters")
    @user.reload
    assert_equal "active", @user.get_setting(:filters, :job_leads)
    assert_equal 12, @user.get_setting(:goals, :weekly_applications)
  end

  test "should ignore unknown top-level settings params" do
    patch settings_url(tab: "goals"), params: {
      settings: {
        hacked: "1",
        goals: { weekly_applications: "12" }
      }
    }

    assert_redirected_to settings_path(tab: "goals")
    @user.reload
    assert_equal 12, @user.get_setting(:goals, :weekly_applications)
    assert_not @user.settings.key?("hacked")
  end

  test "should ignore unknown nested settings params" do
    patch settings_url(tab: "goals"), params: {
      settings: {
        goals: { bogus: "1", weekly_applications: "12" }
      }
    }

    assert_redirected_to settings_path(tab: "goals")
    @user.reload
    assert_equal 12, @user.get_setting(:goals, :weekly_applications)
    assert_not @user.settings.dig("goals")&.key?("bogus")
  end

  test "should ignore scalar settings params without changing settings" do
    @user.update_settings(filters: { job_leads: "active" })

    patch settings_url(tab: "filters"), params: { settings: "foo" }

    assert_redirected_to settings_path(tab: "filters")
    assert_equal "active", @user.reload.get_setting(:filters, :job_leads)
  end

  test "should ignore scalar nested settings params without changing settings" do
    @user.update_settings(goals: { weekly_applications: 12 })

    patch settings_url(tab: "goals"), params: { settings: { goals: "foo" } }

    assert_redirected_to settings_path(tab: "goals")
    assert_equal 12, @user.reload.get_setting(:goals, :weekly_applications)
  end

  test "should reset settings and preserve tab" do
    @user.update_settings(goals: { weekly_applications: 42 })

    patch reset_settings_url(tab: "danger_zone")

    assert_redirected_to settings_path(tab: "danger_zone")
    assert_equal User::DEFAULT_SETTINGS[:goals][:weekly_applications], @user.reload.get_setting(:goals, :weekly_applications)
  end
end
