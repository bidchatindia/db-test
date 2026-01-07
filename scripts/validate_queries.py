#!/usr/bin/env python3
"""
Query Validation Script
Tests all SQL queries from QUESTIONS.md to ensure they work correctly.
"""

import mysql.connector
import re
import sys
from pathlib import Path

# Database connection configuration
DB_CONFIG = {
    'host': 'db',
    'user': 'root',
    'password': 'root',
    'database': 'testdb',
    'port': 3306
}

def parse_questions_file(file_path):
    """Parse QUESTIONS.md and extract questions with their SQL answers."""
    questions = []
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Split by question markers (Q1, Q2, etc.)
    # Pattern: ### Q##. Title\n**Expected:** ...\n\n**Answer:**\n```sql\n...\n```
    question_pattern = r'### (Q\d+)\.\s+(.+?)\n\*\*Expected:\*\*\s+(.+?)\n\n\*\*Answer:\*\*\n```sql\n(.*?)```'
    matches = re.finditer(question_pattern, content, re.DOTALL)
    
    for match in matches:
        q_num = match.group(1)
        q_title = match.group(2).strip()
        expected = match.group(3).strip()
        sql_query = match.group(4).strip()
        
        # Clean up the SQL query
        sql_query = re.sub(r'\n\s*\n', '\n', sql_query)  # Remove extra blank lines
        
        questions.append({
            'number': q_num,
            'title': q_title,
            'expected': expected,
            'sql': sql_query
        })
    
    return questions

def clean_sql_query(sql):
    """Clean SQL query - remove comments and extra whitespace."""
    # Remove single-line comments
    lines = sql.split('\n')
    cleaned_lines = []
    for line in lines:
        # Remove comments but keep the line if it has code
        if '--' in line:
            comment_pos = line.find('--')
            code_part = line[:comment_pos].strip()
            if code_part:
                cleaned_lines.append(code_part)
        else:
            cleaned_lines.append(line.strip())
    
    # Join and clean up
    cleaned = ' '.join(cleaned_lines)
    # Remove extra spaces
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()
    return cleaned

def execute_query(cursor, sql_query, question_num):
    """Execute a query and return results or error."""
    try:
        # Handle stored procedures separately (they use DELIMITER)
        if 'DELIMITER' in sql_query.upper() or 'CREATE PROCEDURE' in sql_query.upper():
            # For stored procedures, we'll skip validation for now
            # They need to be created first, then called
            return {'success': True, 'results': [], 'row_count': 0, 'skipped': True, 'reason': 'Stored procedure - requires manual setup'}
        
        # Split by semicolons to handle multiple statements
        # But be careful with semicolons inside strings or comments
        statements = []
        current_statement = []
        in_string = False
        string_char = None
        
        for char in sql_query:
            if char in ("'", '"', '`') and not in_string:
                in_string = True
                string_char = char
            elif char == string_char and in_string:
                in_string = False
                string_char = None
            
            current_statement.append(char)
            
            if char == ';' and not in_string:
                stmt = ''.join(current_statement).strip()
                if stmt:
                    statements.append(stmt)
                current_statement = []
        
        # Add remaining statement if any
        if current_statement:
            stmt = ''.join(current_statement).strip()
            if stmt:
                statements.append(stmt)
        
        if not statements:
            return {'success': False, 'error': 'No valid SQL statements found'}
        
        results = []
        row_count = 0
        
        for statement in statements:
            statement = statement.strip()
            if not statement:
                continue
            
            # Skip comments-only statements
            if statement.startswith('--') or statement.startswith('/*'):
                continue
            
            # Execute the statement
            cursor.execute(statement)
            
            # Try to fetch results if it's a SELECT, SHOW, DESCRIBE, EXPLAIN
            stmt_upper = statement.upper().strip()
            if any(stmt_upper.startswith(cmd) for cmd in ['SELECT', 'SHOW', 'DESCRIBE', 'DESC', 'EXPLAIN']):
                try:
                    result = cursor.fetchall()
                    if result:
                        results.append(result)
                        row_count += len(result)
                except:
                    pass  # Some queries don't return rows
        
        return {'success': True, 'results': results, 'row_count': row_count}
    except mysql.connector.Error as e:
        return {'success': False, 'error': str(e), 'error_code': e.errno}
    except Exception as e:
        return {'success': False, 'error': str(e), 'error_type': type(e).__name__}

def validate_query_structure(sql_query):
    """Basic validation of query structure."""
    sql_upper = sql_query.upper().strip()
    
    # Check for common SQL keywords
    has_select = 'SELECT' in sql_upper
    has_from = 'FROM' in sql_upper
    
    # Basic structure checks
    if has_select and not has_from:
        return False, "SELECT query missing FROM clause"
    
    return True, None

def test_queries():
    """Main function to test all queries."""
    # Get the questions file path
    # Entire project root is mounted at /workspace
    questions_file = Path('/workspace/QUESTIONS.md')
    
    # Fallback: try relative path
    if not questions_file.exists():
        script_dir = Path(__file__).parent
        project_root = script_dir.parent
        questions_file = project_root / 'QUESTIONS.md'
    
    if not questions_file.exists():
        print(f"Questions file not found: {questions_file}")
        return False
    
    print("="*70)
    print("Query Validation Script")
    print("="*70)
    print(f"Reading questions from: {questions_file}\n")
    
    # Parse questions
    questions = parse_questions_file(questions_file)
    print(f"Found {len(questions)} questions\n")
    
    # Connect to database
    try:
        print("Connecting to database...")
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        print("Connected successfully!\n")
    except mysql.connector.Error as e:
        print(f"Database connection failed: {e}")
        return False
    
    # Test each query
    results = {
        'total': len(questions),
        'passed': 0,
        'failed': 0,
        'skipped': 0,
        'details': []
    }
    
    print("="*70)
    print("Testing Queries")
    print("="*70)
    print()
    
    for i, question in enumerate(questions, 1):
        q_num = question['number']
        title = question['title']
        sql = question['sql']
        
        print(f"[{i}/{len(questions)}] {q_num}: {title[:60]}...")
        
        # Basic structure validation
        is_valid, error_msg = validate_query_structure(sql)
        if not is_valid:
            print(f"   WARNING: Structure validation failed: {error_msg}")
            results['failed'] += 1
            results['details'].append({
                'question': q_num,
                'status': 'FAILED',
                'reason': error_msg
            })
            continue
        
        # Execute query
        result = execute_query(cursor, sql, q_num)
        
        if result.get('skipped'):
            reason = result.get('reason', 'Skipped')
            print(f"   SKIPPED - {reason}")
            results['skipped'] += 1
            results['details'].append({
                'question': q_num,
                'status': 'SKIPPED',
                'reason': reason
            })
        elif result['success']:
            row_count = result.get('row_count', 0)
            print(f"   PASSED - Returned {row_count} row(s)")
            results['passed'] += 1
            results['details'].append({
                'question': q_num,
                'status': 'PASSED',
                'row_count': row_count
            })
        else:
            error = result.get('error', 'Unknown error')
            error_code = result.get('error_code', 'N/A')
            print(f"   FAILED - {error}")
            if error_code != 'N/A':
                print(f"      Error Code: {error_code}")
            results['failed'] += 1
            results['details'].append({
                'question': q_num,
                'status': 'FAILED',
                'error': error,
                'error_code': error_code
            })
        
        print()
    
    # Summary
    print("="*70)
    print("Summary")
    print("="*70)
    print(f"Total Questions: {results['total']}")
    print(f"Passed: {results['passed']}")
    print(f"Failed: {results['failed']}")
    print(f"Skipped: {results['skipped']}")
    print()
    
    # Show failed queries
    if results['failed'] > 0:
        print("="*70)
        print("Failed Queries Details")
        print("="*70)
        for detail in results['details']:
            if detail['status'] == 'FAILED':
                print(f"\n{detail['question']}: {detail.get('reason', detail.get('error', 'Unknown error'))}")
                if 'error_code' in detail:
                    print(f"   Error Code: {detail['error_code']}")
    
    cursor.close()
    conn.close()
    
    return results['failed'] == 0

if __name__ == "__main__":
    success = test_queries()
    sys.exit(0 if success else 1)

