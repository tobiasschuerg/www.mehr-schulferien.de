defmodule MehrSchulferien.Periods do
  @moduledoc """
  The Periods context.
  """

  import Ecto.Query, warn: false

  alias MehrSchulferien.Calendars.Period
  alias MehrSchulferien.Repo

  def fetch_all do
    Repo.all(Period)
  end

  def fetch_period_by_id(id) do
    Repo.get!(Period, id)
  end

  @doc """
  Groups periods with same holiday_or_vacation_type.
  """
  def group_periods_single_year(periods) do
    Enum.chunk_by(periods, & &1.holiday_or_vacation_type.name)
  end

  @doc """
  Groups periods with same holiday_or_vacation_type. This function
  works for many years and returns a `{headers, periods}` tuple.
  """
  def group_periods_multi_year(periods) do
    headers =
      periods
      |> Enum.uniq_by(& &1.holiday_or_vacation_type.name)
      |> Enum.sort(&(Date.day_of_year(&1.starts_on) <= Date.day_of_year(&2.starts_on)))

    periods =
      for period_list <- Enum.chunk_by(periods, & &1.starts_on.year) do
        create_year_periods(period_list, headers)
      end

    {headers, periods}
  end

  defp create_year_periods(periods, headers) do
    for title <- headers do
      Enum.filter(
        periods,
        &(&1.holiday_or_vacation_type.name == title.holiday_or_vacation_type.name)
      )
    end
  end

  @doc """
  Returns a list of periods for a certain time frame.
  """
  def list_school_periods(location_ids, starts_on, ends_on) do
    from(p in Period,
      where:
        p.location_id in ^location_ids and
          p.is_valid_for_students == true and
          p.is_school_vacation == true and
          p.ends_on >= ^starts_on and
          p.starts_on <= ^ends_on,
      order_by: p.starts_on
    )
    |> Repo.all()
    |> Repo.preload(:holiday_or_vacation_type)
  end

  @doc """
  Lists public holiday periods, including weekends, for a certain time frame.
  """
  def list_all_public_periods(location_ids, starts_on, ends_on) do
    location_ids
    |> public_periods_query(starts_on, ends_on)
    |> Repo.all()
    |> Repo.preload(:holiday_or_vacation_type)
  end

  @doc """
  Lists public holiday periods, including weekends, for a certain number of years.
  """
  def list_multi_year_all_public_periods(location_ids, current_year, number_years) do
    {:ok, first_day} = Date.new(current_year, 1, 1)
    {:ok, last_day} = Date.new(current_year + number_years - 1, 12, 31)

    location_ids
    |> public_periods_query(first_day, last_day)
    |> Repo.all()
    |> Repo.preload(:holiday_or_vacation_type)
  end

  @doc """
  Returns a list of public holiday periods for a given date and location_ids.
  """
  def list_public_holiday_periods(location_ids, date) do
    from(p in Period,
      where:
        p.location_id in ^location_ids and
          p.is_public_holiday == true and
          p.ends_on >= ^date and
          p.starts_on <= ^date,
      order_by: p.display_priority
    )
    |> Repo.all()
    |> Repo.preload(:holiday_or_vacation_type)
  end

  @doc """
  Returns a list of periods which indicate that this day is school
  free for students for a given date and location_ids.
  """
  def list_school_free_periods(location_ids, date) do
    from(p in Period,
      where:
        p.location_id in ^location_ids and
          (p.is_valid_for_students == true or
             p.is_valid_for_everybody == true) and
          p.ends_on >= ^date and
          p.starts_on <= ^date,
      order_by: p.display_priority
    )
    |> Repo.all()
    |> Repo.preload(:holiday_or_vacation_type)
  end

  @doc """
  Returns a list of periods for which this date range is a holiday
  period for students.
  """
  def list_school_free_periods(location_ids, starts_on, ends_on) do
    from(p in Period,
      where:
        p.location_id in ^location_ids and
          (p.is_valid_for_students == true or
             p.is_valid_for_everybody == true) and
          p.ends_on >= ^starts_on and
          p.starts_on <= ^ends_on,
      order_by: p.display_priority
    )
    |> Repo.all()
    |> Repo.preload(:holiday_or_vacation_type)
  end

  @doc """
  Returns the next school vacation period that is greater than today.
  """
  def next_school_vacation_period(location_ids) do
    next_school_vacation_period(location_ids, Date.utc_today())
  end

  @doc """
  Returns the next school vacation period that is greater than date.
  """
  def next_school_vacation_period(location_ids, date) do
    from(p in Period,
      where:
        p.location_id in ^location_ids and
          p.is_school_vacation == true and
          p.starts_on > ^date,
      order_by: p.starts_on,
      limit: 1
    )
    |> Repo.one()
    |> Repo.preload(:holiday_or_vacation_type)
  end

  @doc """
  Returns the next public holiday that is greater than today.
  """
  def next_public_holiday_period(location_ids) do
    next_public_holiday_period(location_ids, Date.utc_today())
  end

  @doc """
  Returns the next public holiday that is greater than date.
  """
  def next_public_holiday_period(location_ids, date) do
    from(p in Period,
      where:
        p.location_id in ^location_ids and
          p.is_public_holiday == true and
          p.starts_on > ^date,
      order_by: p.starts_on,
      limit: 1
    )
    |> Repo.one()
    |> Repo.preload(:holiday_or_vacation_type)
  end

  defp public_periods_query(location_ids, starts_on, ends_on) do
    from(p in Period,
      where:
        p.location_id in ^location_ids and
          p.is_valid_for_everybody == true and
          p.ends_on >= ^starts_on and
          p.starts_on <= ^ends_on,
      order_by: p.starts_on
    )
  end

  @doc """
  Returns the result of an SQL query.

  ## Example

      execute_and_load("SELECT * FROM periods LIMIT 2", [], MehrSchulferien.Calendars.Period)
  """
  def execute_and_load(sql, params, model) do
    result = Ecto.Adapters.SQL.query!(Repo, sql, params)
    Enum.map(result.rows, &Repo.load(model, {result.columns, &1}))
  end

  @doc """
  Returns periods with adjoining_duration and array_agg.

  ## Example

      periods_with_adjoining_durations([1,2], ~D[2020-01-01], ~D[2021-01-01])
  """
  # NOTE: riverrun (2020-02-21)
  # Raises the following error:
  # ** (Postgrex.Error) ERROR 42702 (ambiguous_column) column reference "adjoining_duration" is ambiguous
  def periods_with_adjoining_durations(location_ids, starts_on, ends_on) do
    sql = "SELECT
    p.*,
    p.adjoining_duration,
    p.array_agg
 FROM
    (
       SELECT
          p.*,
          holiday_or_vacation_types.name,
          (
             Max(ends_on) OVER (PARTITION BY grp) - Min(starts_on) OVER (PARTITION BY grp)
          )
          + 1 AS adjoining_duration,
          array_agg(p.id) OVER (PARTITION BY grp)
       FROM
          (
             SELECT
                p.*,
                Count(*) FILTER (
             WHERE
                prev_eo < starts_on - INTERVAL '1 day') OVER (
             ORDER BY
                starts_on ) AS grp
             FROM
                (
                   SELECT
                      p.*,
                      MAX(ends_on) OVER (
                   ORDER BY
                      starts_on ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prev_eo
                   FROM
                      (
                         SELECT
                            p.*
                         FROM
                            periods p
                         WHERE
                            location_id IN
                            (
                               " <> Enum.join(location_ids, ", ") <> "
                            )
                            AND starts_on > '" <> Date.to_string(starts_on) <> "'
                            AND starts_on < '" <> Date.to_string(ends_on) <> "'
                            AND
                            (
                               is_valid_for_students = TRUE
                               OR is_valid_for_everybody = TRUE
                            )
                      )
                      p
                )
                p
          )
          p
          LEFT JOIN
             holiday_or_vacation_types
             ON p.holiday_or_vacation_type_id = holiday_or_vacation_types.id
    )
    p
 WHERE
    p.is_school_vacation = TRUE;"

    execute_and_load(sql, [], MehrSchulferien.Calendars.Period)
  end
end
