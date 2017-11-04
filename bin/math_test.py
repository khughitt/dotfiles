#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Simple mental arithmetic quiz script
Keith Hughitt
2017/06/27
"""
import time
import datetime
import random
import operator
import os

_TIME_LIMIT_SECS_ = 300

def main():
    """Main app"""
    t1 = time.time()
    time_elapsed = 0

    # binary score keeper
    score_bits = []

    # keep track of questions and answers for summary
    questions = []
    answers = []
    user_answers = []

    # arithmetic operators
    ops = [
        ('+', operator.add),
        ('-', operator.sub),
        ('×', operator.mul),
        ('/', operator.truediv)
    ]

    # loop until time limit is hit
    i = 1

    while time_elapsed < _TIME_LIMIT_SECS_:
        # randomly select numbers and operation
        ind = random.randint(0, 3)

        # add, sub
        if ind <= 1:
            n1 = random.randint(0, 9999)
            n2 = random.randint(0, 9999)
            ans = ops[ind][1](n1, n2)
        # multiplication
        elif ind == 2:
            n1 = random.randint(0, 99)
            n2 = random.randint(0, 99)
            ans = ops[ind][1](n1, n2)
        # division
        else:
            n2 = random.randint(1, 99)
            ans = random.randint(1, 99)
            n1 = operator.mul(n2, ans)

        # question
        ques = "%d %s %d" % (n1, ops[ind][0], n2)

        # prompt queston
        questions.append(ques)
        answers.append(ans)

        user_ans = int(input(ques + ": "))
        user_answers.append(user_ans)

        if ans == user_ans:
            score_bits.append(1)
        else:
            score_bits.append(0)

        # update counters
        i = i + 1
        time_elapsed = time.time() - t1

    # print results
    print("SUMMARY:")
    print("========")
    for i in range(len(questions)):
        if score_bits[i]:
            rhs = "CORRECT"
        else:
            rhs = "INCORRECT, actual: {:d}".format(answers[i])
        print("{0:<13s}: {1: 6d} ({2:s})".format(questions[i], user_answers[i], rhs))

    print("")
    print("SCORE: %d / %d (%0.2f)" % (sum(score_bits), len(score_bits),
        sum(score_bits) / len(score_bits)))

    # save results
    now = datetime.datetime.now()
    date = now.strftime("%Y-%m-%d %H:%M:%S")
    day = now.strftime("%a")

    with open(os.path.join(os.getenv('HOME'), 'Dropbox', 'math.csv'), 'a') as fp:
        fp.writelines(",".join([day, date, str(sum(score_bits)), str(len(score_bits))]) + '\n')

if __name__ == '__main__':
    main()
