defmodule MehrSchulferienWeb.ViewHelpers do
  @moduledoc """
  Helper functions for use with views.
  """

  alias MehrSchulferien.Calendars

  @version Mix.Project.config()[:version]

  def version, do: @version

  @doc """
  Returns the number of days a holiday period lasts for.
  """
  def number_days([period]) do
    Date.diff(period.ends_on, period.starts_on) + 1
  end

  def number_days(periods) do
    Enum.reduce(periods, 0, fn period, acc ->
      Date.diff(period.ends_on, period.starts_on) + 1 + acc
    end)
  end

  @doc """
  Returns a string showing the date range in DD.MM. or DD.MM.YY format.

  If the from_date and till_date are the same, then just a single date is
  returned.
  """
  def format_date_range(from_date, till_date, short \\ nil)

  def format_date_range(same_date, same_date, short) do
    format_date(same_date, short)
  end

  def format_date_range(from_date, till_date, short) do
    format_date(from_date, short) <> " - " <> format_date(till_date, short)
  end

  def format_date(date) do
    format_date(date, nil)
  end

  def format_date(date, nil) do
    format_date(date, :short) <> "#{date.year |> Integer.to_string() |> String.slice(2, 2)}"
  end

  def format_date(date, :short) do
    "#{add_padding(date.day)}.#{add_padding(date.month)}."
  end

  def weekday(date) do
    case Date.day_of_week(date) do
      1 -> "Montag"
      2 -> "Dienstag"
      3 -> "Mittwoch"
      4 -> "Donnerstag"
      5 -> "Freitag"
      6 -> "Samstag"
      _ -> "Sonntag"
    end
  end

  defp add_padding(entry) do
    entry |> Integer.to_string() |> String.pad_leading(2, "0")
  end

  @doc """
  Returns the year based on the `starts_on` value in the first non-empty period.
  """
  def display_year([[] | rest]), do: display_year(rest)
  def display_year([[period | _] | _]), do: period.starts_on.year

  @doc """
  Returns the html class for a date. This is based on whether the date
  is a holiday period.
  """
  def get_html_class(date, periods) do
    case Calendars.find_all_periods(date, periods) do
      [] -> ""
      [period] -> period.html_class
      periods -> select_html_class(periods)
    end
  end

  defp select_html_class(periods) do
    period = periods |> Enum.sort(&(&1.display_priority >= &2.display_priority)) |> hd
    period.html_class
  end

  @doc """
  Returns the public holiday periods and school holiday periods for a month.
  """
  def list_month_holidays(date, public_periods, school_periods) do
    {Calendars.find_periods_by_month(date, public_periods),
     Calendars.find_periods_by_month(date, school_periods)}
  end

  @doc """
  Returns a comma seperated list of list elements.
  The last comma is replaced with an "und" ("and").
  """
  def comma_join_with_a_final_und(list) do
    case Enum.count(list) do
      0 ->
        ""

      1 ->
        Enum.at(list, 0)

      _ ->
        {first_elements, last_elements} = Enum.split(list, -1)
        [last_element] = last_elements

        Enum.join(first_elements, ", ") <> " und " <> last_element
    end
  end
end
