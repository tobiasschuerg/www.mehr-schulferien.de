defmodule MehrSchulferienWeb.SchoolControllerTest do
  use MehrSchulferienWeb.ConnCase

  alias MehrSchulferien.Calendars

  describe "read city data" do
    setup [:add_school]

    test "shows info for a specific federal state", %{
      conn: conn,
      country: country,
      school: school
    } do
      conn = get(conn, Routes.school_path(conn, :show, country.slug, school.slug))
      assert html_response(conn, 200) =~ school.name
    end

    test "custom meta tags are generated", %{conn: conn, country: country, school: school} do
      conn = get(conn, Routes.school_path(conn, :show, country.slug, school.slug))
      assert html_response(conn, 200) =~ "Schulferientermine für #{school.name}"
    end

    test "returns 404 if country is not the root parent of the school", %{
      conn: conn,
      school: school
    } do
      assert_error_sent 404, fn ->
        get(conn, Routes.school_path(conn, :show, "ch", school.slug))
      end
    end
  end

  describe "write holiday period" do
    setup [:add_school]

    test "creates new period for school", %{
      conn: conn,
      country: country,
      school: school
    } do
      holiday_or_vacation_type =
        insert(:holiday_or_vacation_type, %{country_location_id: country.id})

      today = Date.utc_today()

      attrs = %{
        "created_by_email_address" => "froderick@example.com",
        "ends_on" => Date.add(today, 6),
        "location_id" => school.id,
        "holiday_or_vacation_type_id" => holiday_or_vacation_type.id,
        "starts_on" => Date.add(today, 1)
      }

      conn =
        post(conn, Routes.school_path(conn, :create_period, country.slug, school.slug),
          period: attrs
        )

      assert redirected_to(conn) == Routes.school_path(conn, :show, country.slug, school.slug)
      assert get_flash(conn, :info) =~ "Period created successfully"
      assert [period] = Calendars.list_periods()
      assert period.created_by_email_address == "froderick@example.com"
      assert period.holiday_or_vacation_type_id == holiday_or_vacation_type.id
    end
  end

  defp add_school(_) do
    country = insert(:country, %{slug: "d"})
    federal_state = insert(:federal_state, %{parent_location_id: country.id, slug: "berlin"})
    county = insert(:county, %{parent_location_id: federal_state.id, slug: "berlin"})
    city = insert(:city, %{parent_location_id: county.id, slug: "berlin"})
    school = insert(:school, %{parent_location_id: city.id, slug: "kopernikus-gymnasium"})
    {:ok, %{country: country, school: school}}
  end
end
