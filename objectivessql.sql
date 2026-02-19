-- Choosing the ipl DB
use ipl;

-- Creating a master view 'master_data' for efficient querying.
CREATE OR REPLACE VIEW master_data AS
SELECT
    b.Match_Id,
    m.Season_Id,
    b.Innings_No,
    b.Over_Id,
    b.Ball_Id,
    b.Team_Batting,
    b.Team_Bowling,
    b.Striker,
    b.Non_Striker,
    b.Bowler,
    b.Runs_Scored
FROM ball_by_ball b
JOIN matches m
    ON b.Match_Id = m.Match_Id;
    
    OBJECTIVES:
    
-- 1.	List the different dtypes of columns in table “ball_by_ball”. (using information schema)
SELECT 
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'ball_by_ball';
  
-- 2.	What is the total number of runs scored in 1st season by RCB? (bonus: also include the extra runs using the extra runs table)
SELECT 
    SUM(md.Runs_Scored + COALESCE(er.Extra_Runs, 0)) AS RCB_current_runs_in_1st_season
FROM master_data md
LEFT JOIN extra_runs er
    ON md.Match_Id = er.Match_Id
   AND md.Innings_No = er.Innings_No
   AND md.Over_Id = er.Over_Id
   AND md.Ball_Id = er.Ball_Id
WHERE md.Team_Batting = 2
  AND md.Season_Id = (
        SELECT MIN(Season_Id)
        FROM master_data
    );

-- 3.	How many players were more than the age of 25 during season 2014?
SELECT 
    COUNT(DISTINCT p.Player_Id) AS players_above_25
FROM player p
JOIN player_match pm
    ON p.Player_Id = pm.Player_Id
JOIN matches m
    ON pm.Match_Id = m.Match_Id
JOIN season s
    ON m.Season_Id = s.Season_Id
WHERE s.Season_Year = 2014
  AND TIMESTAMPDIFF(YEAR, p.DOB, '2014-12-31') > 25;
  
  -- 4.	How many matches did RCB win in 2013? 
SELECT 
    COUNT(*) AS rcb_wins_2013
FROM matches m
JOIN team t
    ON m.Match_Winner = t.Team_Id
JOIN season s
    ON m.Season_Id = s.Season_Id
WHERE t.Team_Name = 'Royal Challengers Bangalore'
  AND s.Season_Year = 2013;

-- 5.	List the top 10 players according to their strike rate in the last 4 seasons.
SELECT
    p.Player_Name,
    ROUND((SUM(md.Runs_Scored) * 100.0 / COUNT(md.Ball_Id)), 2) AS strike_rate
FROM master_data md
JOIN player p
    ON md.Striker = p.Player_Id
JOIN (
    SELECT Season_Id
    FROM master_data
    GROUP BY Season_Id
    ORDER BY Season_Id DESC
    LIMIT 4
) s
    ON md.Season_Id = s.Season_Id
GROUP BY p.Player_Id, p.Player_Name
HAVING COUNT(md.Ball_Id) >= 100
ORDER BY strike_rate DESC
LIMIT 10;

-- 6.	What are the average runs scored by each batsman considering all the seasons?
SELECT
    p.Player_Name,
    SUM(md.Runs_Scored) AS current_runs,
    COUNT(DISTINCT md.Match_Id) AS matches_played,
    ROUND(SUM(md.Runs_Scored) / COUNT(DISTINCT md.Match_Id), 2) AS avg_runs
FROM master_data md
JOIN player p
    ON md.Striker = p.Player_Id
GROUP BY p.Player_Id, p.Player_Name
ORDER BY avg_runs DESC;

-- 7.	What are the average wickets taken by each bowler considering all the seasons?
SELECT
    p.Player_Name,
    COUNT(wt.Player_Out) AS current_wickets,
    COUNT(DISTINCT md.Match_Id) AS matches_bowled,
    ROUND(COUNT(wt.Player_Out) / COUNT(DISTINCT md.Match_Id), 2) AS avg_wickets
FROM master_data md
JOIN wicket_taken wt
    ON md.Match_Id = wt.Match_Id
   AND md.Innings_No = wt.Innings_No
   AND md.Over_Id = wt.Over_Id
   AND md.Ball_Id = wt.Ball_Id
JOIN player p
    ON md.Bowler = p.Player_Id
GROUP BY p.Player_Id, p.Player_Name
ORDER BY avg_wickets DESC;

-- 8.	List all the players who have average runs scored greater than the overall average and who have taken wickets greater than the overall average.
WITH batting_avg AS (
    SELECT
        md.Striker AS Player_Id,
        SUM(md.Runs_Scored) / COUNT(DISTINCT md.Match_Id) AS avg_runs
    FROM master_data md
    GROUP BY md.Striker
),
bowling_avg AS (
    SELECT
        md.Bowler AS Player_Id,
        COUNT(wt.Player_Out) / COUNT(DISTINCT md.Match_Id) AS avg_wickets
    FROM master_data md
    JOIN wicket_taken wt
        ON md.Match_Id = wt.Match_Id
       AND md.Innings_No = wt.Innings_No
       AND md.Over_Id = wt.Over_Id
       AND md.Ball_Id = wt.Ball_Id
    GROUP BY md.Bowler
),
overall_avg AS (
    SELECT
        (SELECT AVG(avg_runs) FROM batting_avg) AS overall_avg_runs,
        (SELECT AVG(avg_wickets) FROM bowling_avg) AS overall_avg_wickets
)
SELECT
    p.Player_Name,
    ba.avg_runs,
    oa.overall_avg_runs,
    bw.avg_wickets,
    oa.overall_avg_wickets
FROM batting_avg ba
JOIN bowling_avg bw
    ON ba.Player_Id = bw.Player_Id
JOIN overall_avg oa
JOIN player p
    ON p.Player_Id = ba.Player_Id
WHERE ba.avg_runs > oa.overall_avg_runs
  AND bw.avg_wickets > oa.overall_avg_wickets;
  
  
  -- 9.	Create a table rcb_record table that shows the wins and losses of RCB in an individual venue.

DROP TABLE IF EXISTS rcb_record;
CREATE TABLE rcb_record AS
SELECT
    v.Venue_Id,
    v.Venue_Name,
    SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) AS wins,
    SUM(CASE WHEN m.Match_Winner IS NOT NULL 
              AND m.Match_Winner <> 2 THEN 1 ELSE 0 END) AS losses
FROM matches m
JOIN venue v
    ON m.Venue_Id = v.Venue_Id
WHERE 2 IN (m.Team_1, m.Team_2)
GROUP BY v.Venue_Id, v.Venue_Name;
select * from rcb_record;

-- 10.	What is the impact of bowling style on wickets taken?

SELECT
    bs.Bowling_skill,
    COUNT(wt.Player_Out) AS current_wickets
FROM master_data md
JOIN wicket_taken wt
    ON md.Match_Id = wt.Match_Id
   AND md.Innings_No = wt.Innings_No
   AND md.Over_Id = wt.Over_Id
   AND md.Ball_Id = wt.Ball_Id
JOIN player p
    ON md.Bowler = p.Player_Id
JOIN bowling_style bs
    ON p.Bowling_skill = bs.Bowling_Id
GROUP BY bs.Bowling_skill
ORDER BY current_wickets DESC;

/* 11.	Write the SQL query to provide a status of whether the performance of the team is better than 
the previous year's performance on the basis of the number of runs scored by the team in the season and the number of wickets taken.*/
WITH season_perf AS (
    SELECT
        s.Season_Year,
        t.Team_Name,
        SUM(md.Runs_Scored) AS current_runs,
        COUNT(wt.Player_Out) AS current_wickets
    FROM master_data md
    JOIN matches m
        ON md.Match_Id = m.Match_Id
    JOIN season s
        ON m.Season_Id = s.Season_Id
    JOIN team t
        ON md.Team_Batting = t.Team_Id
    LEFT JOIN wicket_taken wt
        ON md.Match_Id = wt.Match_Id
       AND md.Innings_No = wt.Innings_No
       AND md.Over_Id = wt.Over_Id
       AND md.Ball_Id = wt.Ball_Id
    WHERE t.Team_Name = 'Royal Challengers Bangalore'
    GROUP BY s.Season_Year, t.Team_Name
),
season_compare AS (
    SELECT
        Season_Year,
        Team_Name,
        current_runs,
        current_wickets,
        LAG(current_runs) OVER (ORDER BY Season_Year) AS prev_season_runs,
        LAG(current_wickets) OVER (ORDER BY Season_Year) AS prev_season_wickets
    FROM season_perf
)
SELECT
    Season_Year,
    Team_Name,
    current_runs,
    current_wickets,
    prev_season_runs,
    prev_season_wickets,
    CASE
        WHEN current_runs > prev_season_runs 
         AND current_wickets > prev_season_wickets THEN 'Better'
        WHEN current_runs < prev_season_runs 
         AND current_wickets < prev_season_wickets THEN 'Worse'
        ELSE 'Mixed'
    END AS performance_status
FROM season_compare
WHERE prev_season_runs IS NOT NULL;


-- 12.	Can you derive more KPIs for the team strategy?

1. Boundary Dependency KPI
SELECT
    md.Striker AS Player_Id,
    p.Player_Name,
    SUM(md.Runs_Scored) AS Total_Runs_Scored,
    SUM(CASE 
            WHEN md.Runs_Scored IN (4, 6) THEN md.Runs_Scored 
            ELSE 0 
        END) AS Runs_From_Boundaries,
    ROUND(
        (SUM(CASE WHEN md.Runs_Scored IN (4, 6) THEN md.Runs_Scored ELSE 0 END) 
        / SUM(md.Runs_Scored)) * 100, 2
    ) AS Boundary_Percentage
FROM master_data md
JOIN player p
    ON md.Striker = p.Player_Id
JOIN (
    SELECT Season_Id
    FROM master_data
    GROUP BY Season_Id
    ORDER BY Season_Id DESC
    LIMIT 4
) s
    ON md.Season_Id = s.Season_Id
GROUP BY md.Striker, p.Player_Name
HAVING Total_Runs_Scored > 800
   AND Boundary_Percentage > 60
ORDER BY Boundary_Percentage DESC;

2. Player Dependency KPI
WITH last_4_seasons AS (
    SELECT Season_Id
    FROM master_data
    GROUP BY Season_Id
    ORDER BY Season_Id DESC
    LIMIT 4
),
team_total_runs AS (
    SELECT
        md.Team_Batting AS Team_Id,
        SUM(md.Runs_Scored) AS team_runs
    FROM master_data md
    JOIN last_4_seasons l4
        ON md.Season_Id = l4.Season_Id
    GROUP BY md.Team_Batting
),
player_team_runs AS (
    SELECT
        md.Team_Batting AS Team_Id,
        t.Team_Name,
        md.Striker AS Player_Id,
        p.Player_Name,
        SUM(md.Runs_Scored) AS player_runs
    FROM master_data md
    JOIN last_4_seasons l4
        ON md.Season_Id = l4.Season_Id
    JOIN team t
        ON md.Team_Batting = t.Team_Id
    JOIN player p
        ON md.Striker = p.Player_Id
    GROUP BY md.Team_Batting, t.Team_Name, md.Striker, p.Player_Name
),
dependency_rank AS (
    SELECT
        ptr.Team_Id,
        ptr.Team_Name,
        ptr.Player_Name,
        ROUND((ptr.player_runs * 100.0) / ttr.team_runs, 2) AS dependency_percentage,
        ROW_NUMBER() OVER (
            PARTITION BY ptr.Team_Id
            ORDER BY (ptr.player_runs * 1.0 / ttr.team_runs) DESC
        ) AS rn
    FROM player_team_runs ptr
    JOIN team_total_runs ttr
        ON ptr.Team_Id = ttr.Team_Id
)
SELECT
    Team_Name,
    Player_Name,
    dependency_percentage
FROM dependency_rank
WHERE rn = 1
ORDER BY dependency_percentage DESC;


3. Star players KPI
SELECT
    p.Player_Id,
    p.Player_Name,
    SUM(CASE WHEN s.Man_of_the_Series = p.Player_Id THEN 1 ELSE 0 END) AS Man_of_Series_Count,
    SUM(CASE WHEN s.Orange_Cap = p.Player_Id THEN 1 ELSE 0 END) AS Orange_Cap_Count,
    SUM(CASE WHEN s.Purple_Cap = p.Player_Id THEN 1 ELSE 0 END) AS Purple_Cap_Count,
    (
        SUM(CASE WHEN s.Man_of_the_Series = p.Player_Id THEN 1 ELSE 0 END) * 3 +
        SUM(CASE WHEN s.Orange_Cap = p.Player_Id THEN 1 ELSE 0 END) * 2 +
        SUM(CASE WHEN s.Purple_Cap = p.Player_Id THEN 1 ELSE 0 END) * 2
    ) AS Star_Player_Weightage
FROM season s
JOIN player p
    ON p.Player_Id IN (s.Man_of_the_Series, s.Orange_Cap, s.Purple_Cap)
GROUP BY p.Player_Id, p.Player_Name
HAVING Star_Player_Weightage > 0
ORDER BY Star_Player_Weightage DESC;

4. All-rounders KPI
SELECT
    p.Player_Name,
    SUM(md.Runs_Scored) AS Total_Runs,
    COUNT(wt.Player_Out) AS Total_Wickets
FROM master_data md
LEFT JOIN wicket_taken wt
    ON md.Match_Id = wt.Match_Id
   AND md.Innings_No = wt.Innings_No
   AND md.Over_Id = wt.Over_Id
   AND md.Ball_Id = wt.Ball_Id
JOIN player p
    ON p.Player_Id IN (md.Striker, md.Bowler)
JOIN (
    SELECT Season_Id
    FROM master_data
    GROUP BY Season_Id
    ORDER BY Season_Id DESC
    LIMIT 4
) s
    ON md.Season_Id = s.Season_Id
GROUP BY p.Player_Id, p.Player_Name
HAVING Total_Runs > 500 AND Total_Wickets > 20
ORDER BY Total_Runs desc, Total_Wickets desc;

-- 13.	Using SQL, write a query to find out the average wickets taken by each bowler in each venue. 
-- Also, rank the gender according to the average value.

WITH bowler_venue_stats AS (
    SELECT
        v.Venue_Id,
        v.Venue_Name,
        p.Player_Name,
        COUNT(wt.Player_Out) AS Total_Wickets_Taken,
        COUNT(DISTINCT m.Match_Id) AS Total_Matches_Played,
        ROUND(
            COUNT(wt.Player_Out) / COUNT(DISTINCT m.Match_Id),
            2
        ) AS Avg_Wickets
    FROM wicket_taken wt
    JOIN ball_by_ball bb
        ON wt.Match_Id = bb.Match_Id
       AND wt.Innings_No = bb.Innings_No
       AND wt.Over_Id = bb.Over_Id
       AND wt.Ball_Id = bb.Ball_Id
    JOIN matches m
        ON wt.Match_Id = m.Match_Id
    JOIN venue v
        ON m.Venue_Id = v.Venue_Id
    JOIN player p
        ON bb.Bowler = p.Player_Id
    GROUP BY v.Venue_Id, v.Venue_Name, p.Player_Name
    HAVING COUNT(DISTINCT m.Match_Id) > 10
)
SELECT
    Venue_Name,
    Player_Name,
    Total_Matches_Played,
    Total_Wickets_Taken,
    Avg_Wickets,
    DENSE_RANK() OVER (ORDER BY Avg_Wickets DESC) AS Venue_Rank
FROM bowler_venue_stats
ORDER BY Venue_Rank;


-- 14.	Which of the given players have consistently performed well in past seasons? (will you use any visualization to solve the problem)
1. Batting Consistency:
WITH batting_season_perf AS (
    SELECT
        md.Striker AS Player_Id,
        p.Player_Name,
        md.Season_Id,
        SUM(md.Runs_Scored) AS Season_Runs,
        COUNT(md.Ball_Id) AS Balls_Faced
    FROM master_data md
    JOIN player p
        ON md.Striker = p.Player_Id
    GROUP BY md.Striker, p.Player_Name, md.Season_Id
),
batting_consistency AS (
    SELECT
        Player_Id,
        Player_Name,
        COUNT(Season_Id) AS Seasons_Played,
        SUM(Season_Runs) AS Total_Runs,
        SUM(Balls_Faced) AS Total_Balls,
        ROUND(AVG(Season_Runs), 2) AS Avg_Runs_Per_Season,
        ROUND(STDDEV(Season_Runs), 2) AS Runs_Variation
    FROM batting_season_perf
    GROUP BY Player_Id, Player_Name
)
SELECT
    Player_Name,
    Seasons_Played,
    Avg_Runs_Per_Season,
    Runs_Variation
FROM batting_consistency
WHERE Seasons_Played > 3
  AND Total_Balls >= 300
ORDER BY Runs_Variation ASC, Avg_Runs_Per_Season DESC;

2. Bowling Consistency:

WITH bowling_season_perf AS (
    SELECT
        md.Bowler AS Player_Id,
        p.Player_Name,
        md.Season_Id,
        COUNT(wt.Player_Out) AS Season_Wickets
    FROM master_data md
    JOIN wicket_taken wt
        ON md.Match_Id = wt.Match_Id
       AND md.Innings_No = wt.Innings_No
       AND md.Over_Id = wt.Over_Id
       AND md.Ball_Id = wt.Ball_Id
    JOIN player p
        ON md.Bowler = p.Player_Id
    GROUP BY md.Bowler, p.Player_Name, md.Season_Id
),
bowling_consistency AS (
    SELECT
        Player_Id,
        Player_Name,
        COUNT(Season_Id) AS Seasons_Played,
        SUM(Season_Wickets) AS Total_Wickets,
        ROUND(AVG(Season_Wickets), 2) AS Avg_Wickets_Per_Season,
        ROUND(STDDEV(Season_Wickets), 2) AS Wickets_Variation
    FROM bowling_season_perf
    GROUP BY Player_Id, Player_Name
)
SELECT
    Player_Name,
    Seasons_Played,
    Avg_Wickets_Per_Season,
    Wickets_Variation
FROM bowling_consistency
WHERE Seasons_Played > 3
  AND Total_Wickets >= 30
ORDER BY Wickets_Variation ASC, Avg_Wickets_Per_Season DESC;


-- 15.	Are there players whose performance is more suited to specific venues or conditions? (how would you present this using charts?) 
 
1.Batting: Venue-wise Player Performance
SELECT
    v.Venue_Name,
    p.Player_Name,
    COUNT(DISTINCT md.Match_Id) AS Matches_Played,
    SUM(md.Runs_Scored) AS Total_Runs,
    ROUND(SUM(md.Runs_Scored) / COUNT(DISTINCT md.Match_Id), 2) AS Avg_Runs_Per_Match
FROM master_data md
JOIN matches m
    ON md.Match_Id = m.Match_Id
JOIN venue v
    ON m.Venue_Id = v.Venue_Id
JOIN player p
    ON md.Striker = p.Player_Id
GROUP BY  md.Striker, p.Player_Name, v.Venue_Name
HAVING COUNT(DISTINCT md.Match_Id) >= 5
and count(md.Ball_Id)>100
ORDER BY Total_Runs DESC
limit 20;

2.Bowling: Venue-wise Player Performance
SELECT
    v.Venue_Name,
    p.Player_Name,
    COUNT(DISTINCT m.Match_Id) AS Matches_Played,
    COUNT(wt.Player_Out) AS Total_Wickets,
    ROUND(COUNT(wt.Player_Out) / COUNT(DISTINCT m.Match_Id),2) AS Avg_Wickets_Per_Match
FROM wicket_taken wt
JOIN ball_by_ball bb
    ON wt.Match_Id = bb.Match_Id
   AND wt.Innings_No = bb.Innings_No
   AND wt.Over_Id = bb.Over_Id
   AND wt.Ball_Id = bb.Ball_Id
JOIN matches m
    ON wt.Match_Id = m.Match_Id
JOIN venue v
    ON m.Venue_Id = v.Venue_Id
JOIN player p
    ON bb.Bowler = p.Player_Id
GROUP BY bb.Bowler,p.Player_Name, v.Venue_Name
HAVING COUNT(DISTINCT m.Match_Id) >= 5
ORDER BY Total_Wickets DESC
limit 20;

 





