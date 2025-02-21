import pyodbc
import struct
import pandas as pd
from datetime import datetime
import os
from azure import identity
import locale

def get_conn():
    server = "serverrecommendations.database.windows.net"
    database = "db_recommendation"
    driver = "{ODBC Driver 18 for SQL Server}"

    connection_string = (
        f"Driver={driver};"
        f"Server=tcp:{server},1433;"
        f"Database={database};"
        f"Encrypt=yes;"
        f"TrustServerCertificate=no;"
        "Connection Timeout=30"
    )

    credential = identity.DefaultAzureCredential(exclude_interactive_browser_credential=False)
    token_bytes = credential.get_token("https://database.windows.net/.default").token.encode("UTF-16-LE")
    token_struct = struct.pack(f'<I{len(token_bytes)}s', len(token_bytes), token_bytes)
    SQL_COPT_SS_ACCESS_TOKEN = 1256
    return pyodbc.connect(connection_string, attrs_before={SQL_COPT_SS_ACCESS_TOKEN: token_struct})

def get_recommendations(conn):
    query = "EXEC sp_GetRecommendations"
    return pd.read_sql(query, conn)

def generate_summary(df):
    pivot = pd.pivot_table(
        df,
        values='Id',
        index=['Category'],
        columns=['Impact'],
        aggfunc='count',
        fill_value=0
    )
    
    for col in ['High', 'Medium', 'Low']:
        if col not in pivot.columns:
            pivot[col] = 0
    
    pivot['Total'] = pivot.sum(axis=1)
    
    return pivot

def generate_html_table_rows(df):
    rows = []
    for index, row in df.iterrows():
        rows.append(
            f"<tr><td>{index}</td>"
            f"<td class='high-impact'>{int(row.get('High', 0))}</td>"
            f"<td class='medium-impact'>{int(row.get('Medium', 0))}</td>"
            f"<td class='low-impact'>{int(row.get('Low', 0))}</td>"
        )
    return "\n".join(rows)

def generate_cost_recommendations_rows(df):
    # filter rows where Category is Cost
    df = df[df['Category'] == 'Cost']
    
    # Define the order for Impact
    impact_order = ['High', 'Medium', 'Low']
    df['Impact'] = pd.Categorical(df['Impact'], categories=impact_order, ordered=True)
    df = df.sort_values('Impact')

    rows = []
    for _, row in df.iterrows():
        eta_date = row['ProposedETA'].strftime('%Y-%m-%d') if pd.notnull(row['ProposedETA']) else ''
        last_update_date = row['LastUpdateDatetime'].strftime('%Y-%m-%d %H:%M:%S') if pd.notnull(row['LastUpdateDatetime']) else ''
        impactClass = row['Impact'].lower() + '-impact'
        
        rows.append(
            f"<tr>"
            f"<td class='{impactClass}'>{row['Impact']}</td>"
            f"<td>{row['Description']}</td>"
            f"<td>{row['CostPotentialSavingsAmount']} {row['CostPotentialSavingsCcy']}</td>"
            f"<td>{row['ResourceName'] if row['ResourceName'] else ''}</td>"
            f"<td>{eta_date}</td>"
            f"<td>{last_update_date}</td>"
            f"<td><a href='https://portal.azure.com/#view/Microsoft_Azure_Expert/AdvisorMenuBlade/~/overview'>View</a></td>"
            f"</tr>"
        )
    return "\n".join(rows)

def generate_security_recommendations_rows(df):
    # filter rows where Category is Security
    df = df[df['Category'] == 'Security']
    
    # Define the order for Impact
    impact_order = ['High', 'Medium', 'Low']
    df['Impact'] = pd.Categorical(df['Impact'], categories=impact_order, ordered=True)
    df = df.sort_values('Impact')

    rows = []
    for _, row in df.iterrows():
        eta_date = row['ProposedETA'].strftime('%Y-%m-%d') if pd.notnull(row['ProposedETA']) else ''
        last_update_date = row['LastUpdateDatetime'].strftime('%Y-%m-%d %H:%M:%S') if pd.notnull(row['LastUpdateDatetime']) else ''
        impactClass = row['Impact'].lower() + '-impact'
        
        rows.append(
            f"<tr>"
            f"<td class='{impactClass}'>{row['Impact']}</td>"
            f"<td>{row['Description'] if row['Description'] else ''}</td>"
            f"<td>{row['ResourceName'] if row['ResourceName'] else ''}</td>"
            f"<td>{eta_date}</td>"
            f"<td>{last_update_date}</td>"
            f"<td><a href='{row['DocumentationLink']}'>View</a></td>"
            f"</tr>"
        )
    return "\n".join(rows)

def save_html_report(html_content, cloud_provider, subscription_name):
    output_dir = os.path.join(os.path.dirname(__file__), 'output')
    os.makedirs(output_dir, exist_ok=True)
    
    filename = f'recommendations_summary_{cloud_provider}_{subscription_name}.html'
    filepath = os.path.join(output_dir, filename)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    return filepath

def main():
    try:
        conn = get_conn()
        df = get_recommendations(conn)
        
        grouped = df.groupby(['CloudProvider', 'SubscriptionName'])
        
        for (cloud_provider, subscription_name), group in grouped:
            summary_df = generate_summary(group)
            
            potential_cost_savings = group['CostPotentialSavingsAmount'].sum()
            cost_rows = group[group['Category'] == 'Cost']
            potential_cost_savings_ccy = cost_rows['CostPotentialSavingsCcy'].iloc[0] if not cost_rows.empty else ''
            
            # Set locale to US for currency formatting
            locale.setlocale(locale.LC_ALL, 'en_US.UTF-8')
            potential_cost_savings_formatted = locale.currency(potential_cost_savings, grouping=True)
            
            template_path = os.path.join(os.path.dirname(__file__), 'templates', 'email_template.html')
            with open(template_path, 'r') as f:
                template = f.read()
            
            html_content = template.format(
                generation_date=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                total_recommendations=len(group),
                table_rows=generate_html_table_rows(summary_df),
                recommendations_rows=generate_cost_recommendations_rows(group),
                security_recommendations_rows=generate_security_recommendations_rows(group),
                cloud_provider=cloud_provider,
                subscription_name=subscription_name,
                potential_cost_savings=potential_cost_savings_formatted,
                potential_cost_savings_ccy=potential_cost_savings_ccy
            )
            
            output_file = save_html_report(html_content, cloud_provider, subscription_name)
            print(f"Summary report saved successfully to: {output_file}")
        
    except Exception as e:
        print(f"Error: {str(e)}")
        raise

if __name__ == "__main__":
    main()