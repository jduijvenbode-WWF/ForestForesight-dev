install.packages('rsconnect')

rsconnect::setAccountInfo(name='forestforesight-wwf', token='915673C87CFAE302B2CEE5CF1DFA477B', secret='4XcVnkbbNGu+zpjATQa9pXtsnQ0wfYPWkJLOwhHS')

library(rsconnect)
rsconnect::deployApp()
